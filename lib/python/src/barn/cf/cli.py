"""barn-cf: roll Cloudflare account API tokens kept in 1Password.

    barn-cf rotate <item> [--dry-run] [--yes] [--skip-push]
    barn-cf link <item> --account-id ID
    barn-cf show <item>

<item> is service.subsystem.name or three words: service subsystem name.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from datetime import datetime, timezone

from onepassword import Client

from barn.cf import cloudflare, hooks, items
from barn.cf.cloudflare import CloudflareError
from barn.op import config, vault
from barn.op.naming import ItemName, NamingError, add_item_argument

RAW = argparse.RawDescriptionHelpFormatter

# The admin token: account permission "Account API Tokens Write" (dashboard:
# Account > API Tokens > Edit). It lives only in 1Password. Default in config/barn.env.
ADMIN_ITEM = os.environ.get("BARN_CF_ADMIN_ITEM") or "barn.cloudflare.token-admin"
SAVE_ATTEMPTS = 3


def info(msg: str) -> None:
    print(msg, file=sys.stderr)


def check_title(item: str | list[str]) -> str:
    return ItemName.parse(item).title


async def open_vault() -> tuple[Client, str]:
    client = await vault.connect()
    return client, await vault.vault_id(client)


async def admin_token(client: Client, vid: str) -> str:
    return (await items.load(client, vid, ADMIN_ITEM)).require(items.SECRET)


# ------------------------------------------------------------------ rotate

async def rotate(args: argparse.Namespace) -> int:
    title = check_title(args.item)
    hook = hooks.for_item(title)
    if hook and not hook.ready and not args.skip_push:
        raise SystemExit(
            f"error: {title} is pushed by a hook that isn't built yet ({hook.description}).\n"
            "Rolling kills the old secret, so that consumer would break. Pass --skip-push\n"
            "to roll anyway and update it by hand."
        )

    client, vid = await open_vault()
    target = await items.load(client, vid, title)
    account_id = target.require(items.ACCOUNT_ID)
    token_id = target.require(items.TOKEN_ID)
    admin = await admin_token(client, vid)

    details = cloudflare.get_token(account_id, token_id, admin)
    info(f"{title}: Cloudflare token '{details.name}' ({details.id}), status {details.status}"
         + (f", expires {details.expires_on}" if details.expires_on else ""))
    push_note = (
        "no push needed" if not hook
        else "push skipped (--skip-push)" if args.skip_push
        else f"then {hook.description}"
    )
    info(f"  roll the secret, save it to 1Password, {push_note}")
    if args.dry_run:
        info("Dry run: nothing changed.")
        return 0
    if not args.yes:
        if not sys.stdin.isatty():
            raise SystemExit("error: not a terminal; pass --yes to roll without asking")
        if input("The current secret stops working immediately. Roll it? [y/N] ").strip().lower() != "y":
            info("Cancelled.")
            return 1

    new_value = cloudflare.roll_token(account_id, token_id, admin)
    info("Rolled. The old secret no longer works.")

    try:
        check = cloudflare.verify(account_id, new_value)
        info(f"New secret verified (status {check.status}).")
    except CloudflareError as e:
        info(f"warning: couldn't verify the new secret ({e}); saving it anyway")

    target.set(items.SECRET, new_value, concealed=True)
    target.set(items.LAST_ROTATED, datetime.now(timezone.utc).isoformat(timespec="seconds"))
    for attempt in range(1, SAVE_ATTEMPTS + 1):
        try:
            await items.save(client, target)
            break
        except Exception as e:  # SDK raises plain Exceptions
            info(f"error: saving to 1Password failed (attempt {attempt}/{SAVE_ATTEMPTS}): {e}")
            if attempt == SAVE_ATTEMPTS:
                # Last resort: the only copy of the new secret is in memory.
                info(f"Put this value in {title} by hand; it is the only copy:")
                print(new_value)
                return 1
            if sys.stdin.isatty():
                input("Fix 1Password (unlock it?), then press Enter to retry. ")
    info(f"Saved to {title} in {config.VAULT}.")

    if hook and not args.skip_push:
        try:
            hook.push(title, new_value)
        except hooks.PushError as e:
            info(f"error: push failed: {e}")
            return 3
        info(f"Pushed: {hook.description}.")
    elif hook:
        info(f"Remember: {hook.description} by hand.")
        return 3
    return 0


# -------------------------------------------------------------------- link

async def link(args: argparse.Namespace) -> int:
    """Store account id and token id on an item; the id comes from verifying the token."""
    title = check_title(args.item)
    client, vid = await open_vault()
    target = await items.load(client, vid, title)
    secret = target.require(items.SECRET)
    check = cloudflare.verify(args.account_id, secret)
    target.set(items.ACCOUNT_ID, args.account_id)
    target.set(items.TOKEN_ID, check.id)
    await items.save(client, target)
    info(f"Linked {title} to Cloudflare token {check.id} (status {check.status}).")
    return 0


# -------------------------------------------------------------------- show

async def show(args: argparse.Namespace) -> int:
    title = check_title(args.item)
    client, vid = await open_vault()
    target = await items.load(client, vid, title)
    account_id = target.require(items.ACCOUNT_ID)
    token_id = target.require(items.TOKEN_ID)
    details = cloudflare.get_token(account_id, token_id, await admin_token(client, vid))
    hook = hooks.for_item(title)
    print(f"item:         {title}")
    print(f"token:        {details.name} ({details.id})")
    print(f"status:       {details.status}")
    print(f"expires:      {details.expires_on or 'never'}")
    print(f"last rotated: {target.get(items.LAST_ROTATED) or 'never (by barn-cf)'}")
    print(f"push:         {hook.description + ('' if hook.ready else ' (stub)') if hook else 'none'}")
    return 0


# -------------------------------------------------------------------- main

def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="barn-cf",
        description=(
            "Roll Cloudflare account API tokens kept in 1Password.\n\n"
            f"Uses the admin token in '{ADMIN_ITEM}' (override with BARN_CF_ADMIN_ITEM),\n"
            f"read from the {config.VAULT} vault through the 1Password app (Touch ID)."
        ),
        formatter_class=RAW,
    )
    sub = p.add_subparsers(dest="command", required=True, metavar="<command>")

    r = sub.add_parser(
        "rotate",
        help="roll a token's secret, save it to 1Password, push it to its consumer",
        description=(
            "Roll a token's secret with Cloudflare's roll API: same token, same\n"
            "permissions, new secret; the old secret stops working at once. Saves the\n"
            "new value to the item, then runs the item's push hook, if it has one."
        ),
        epilog="example:\n  barn-cf rotate terraform.cloudflare.dns --dry-run",
        formatter_class=RAW,
    )
    add_item_argument(r, "caddy.acme.cloudflare")
    r.add_argument("--dry-run", action="store_true", help="check everything, roll nothing")
    r.add_argument("--yes", "-y", action="store_true", help="don't ask before rolling")
    r.add_argument("--skip-push", action="store_true",
                   help="don't run the push hook; you update the consumer by hand")
    r.set_defaults(func=rotate)

    lk = sub.add_parser(
        "link",
        help="record a token's account ID and token ID on its item (once per item)",
        description=(
            "Record the Cloudflare account ID and token ID on an item that already\n"
            "holds the token (e.g. one made with `barn-op new-item ApiCredentials`).\n"
            "The token ID is looked up by verifying the token itself."
        ),
        epilog="example:\n  barn-cf link caddy.acme.cloudflare --account-id 0123456789abcdef0123456789abcdef",
        formatter_class=RAW,
    )
    add_item_argument(lk, "caddy.acme.cloudflare")
    lk.add_argument("--account-id", required=True, help="32-character Cloudflare account ID")
    lk.set_defaults(func=link)

    s = sub.add_parser("show", help="show a token's name, status and last rotation (no secrets)")
    add_item_argument(s, "terraform.cloudflare.dns")
    s.set_defaults(func=show)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(sys.argv[1:] if argv is None else argv)
    try:
        return asyncio.run(args.func(args))
    except NamingError as e:
        info(f"error: {e}")
        return 2
    except CloudflareError as e:
        info(f"error: Cloudflare: {e}")
        return 1
    except KeyboardInterrupt:
        return 130
