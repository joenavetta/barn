"""barn-op: create and list 1Password items that follow docs/secrets.md.

    barn-op new-item <category> <service>.<subsystem>.<name> --target T --description "..."
    barn-op list-items [--service S] [--subsystem S] [--category C] [--target T] [--json]
    barn-op proxmox-token <node>
    barn-op completion {zsh,bash}
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys

import shtab
from onepassword import ItemCategory

from barn.op import config, naming, proxmox, sshkeys, vault
from barn.op.naming import ItemName, NamingError
from barn.op.secrets_input import read_secret

RAW = argparse.RawDescriptionHelpFormatter


def info(msg: str) -> None:
    print(msg, file=sys.stderr)


# ---------------------------------------------------------------- new-item

# One sub-command per category, so help and options fit the item type.
# Keys are the lowercased SDK category names; matching is case-insensitive.
NEW_ITEM_TYPES = {
    "login": dict(
        category=ItemCategory.LOGIN,
        help="account with a username and password (web UIs, admin users, DB users)",
        description="Create a Login item.\nThe password is generated unless you pass --prompt.",
        example=(
            "barn-op new-item Login opnsense webui root --target opnsense --username root \\\n"
            f"    --url https://opnsense.{config.HOME_DOMAIN} --prompt \\\n"
            '    --description "OPNsense web UI root account"'
        ),
    ),
    "password": dict(
        category=ItemCategory.PASSWORD,
        help="secret with no username (encryption passphrases, Wi-Fi keys)",
        description="Create a Password item.\nThe password is generated unless you pass --prompt.",
        example=(
            "barn-op new-item Password pbs.encryption.default --target pbs --length 48 \\\n"
            '    --description "Proxmox Backup Server client encryption passphrase"'
        ),
    ),
    "sshkey": dict(
        category=ItemCategory.SSHKEY,
        help="SSH key pair, generated locally; prints the public key",
        description=(
            "Create an SSH Key item.\n"
            "The key pair is generated locally, the private key goes straight to 1Password,\n"
            "and the public key is printed."
        ),
        example=(
            "barn-op new-item SshKey home ssh admin --target home \\\n"
            "    --description \"Joe's admin key for all hosts\""
        ),
    ),
    "apicredentials": dict(
        category=ItemCategory.APICREDENTIALS,
        help="API token, key, or SMTP token you paste in",
        description=(
            "Create an API Credential item.\n"
            "The token is read from stdin when piped, otherwise from a hidden prompt (asked\n"
            "twice). It's never a command-line argument."
        ),
        example=(
            "pbpaste | barn-op new-item ApiCredentials proxmox smtp notifications --target proton \\\n"
            '    --username notifications@cowshed.cc --description "Proxmox notification email"'
        ),
    ),
}


def add_new_item(sub: argparse._SubParsersAction) -> None:
    p = sub.add_parser(
        "new-item",
        help="create an item named <service>.<subsystem>.<name>",
        description=(
            "Create a 1Password item named <service>.<subsystem>.<name>.\n\n"
            "Give the name dotted (proxmox.smtp.notifications) or as three words\n"
            "(proxmox smtp notifications).\n\n"
            f"The item goes in the {config.VAULT} vault, tagged\n"
            "service/<service>, subsystem/<subsystem> and target/<target>, with the\n"
            "description in its notes. The category is case-insensitive.\n\n"
            "Run `barn-op new-item <category> --help` for that category's options."
        ),
        formatter_class=RAW,
    )
    types = p.add_subparsers(dest="category", required=True, metavar="<category>")
    for key, t in NEW_ITEM_TYPES.items():
        tp = types.add_parser(
            key,
            help=f"{t['category'].value}: {t['help']}",
            description=t["description"],
            epilog="example:\n  " + t["example"].replace("\n", "\n  "),
            formatter_class=RAW,
        )
        naming.add_item_argument(tp)
        tp.add_argument("--target", required=True, help="system it grants access to, e.g. proton")
        tp.add_argument("--description", required=True, help="what it's for; goes in the notes")
        if key == "login":
            tp.add_argument("--username", required=True, help="login name")
            tp.add_argument("--url", help="website or console URL")
        if key == "apicredentials":
            tp.add_argument("--username", help="key ID, user, or SMTP login, if the token has one")
        if key in ("login", "password"):
            tp.add_argument("--prompt", action="store_true",
                            help="enter an existing secret instead of generating one")
            tp.add_argument("--length", type=int, default=32,
                            help="generated password length (default 32)")
        if key == "sshkey":
            tp.add_argument("--key-type", choices=sshkeys.KEY_TYPES, default="ed25519",
                            help="key type (default ed25519)")
        tp.add_argument("--dry-run", action="store_true",
                        help="validate and show what would be created; doesn't touch 1Password")
        tp.set_defaults(func=cmd_new_item, category_key=key)


def build_item(args: argparse.Namespace) -> tuple[vault.NewItem, str | None]:
    """Validate args and assemble the item. Returns (item, public key or None)."""
    name = ItemName.parse(args.item)
    category = NEW_ITEM_TYPES[args.category_key]["category"]
    item = vault.NewItem(
        title=name.title,
        category=category,
        tags=naming.tags(name.service, name.subsystem, args.target),
        notes=args.description,
        username=getattr(args, "username", None),
        url=getattr(args, "url", None),
    )
    public_key = None
    if args.dry_run:
        return item, None
    if category == ItemCategory.SSHKEY:
        item.secret, public_key = sshkeys.generate(args.key_type, name.title)
    elif category == ItemCategory.APICREDENTIALS:
        item.secret = read_secret(f"Token for {name.title}")
    elif args.prompt:
        item.secret = read_secret(f"Secret for {name.title}")
    else:
        item.secret = vault.generate_password(args.length)
    return item, public_key


async def create_item(item: vault.NewItem) -> None:
    client = await vault.connect()
    vid = await vault.vault_id(client)
    if await vault.item_exists(client, vid, item.title):
        raise SystemExit(
            f"error: '{item.title}' already exists in {config.VAULT}; edit or archive it instead"
        )
    await vault.create(client, vid, item)


def cmd_new_item(args: argparse.Namespace) -> int:
    item, public_key = build_item(args)
    if args.dry_run:
        info(f"Dry run OK: would create {item.category.value} '{item.title}' in {config.VAULT}")
        info(f"  tags:  {', '.join(item.tags)}")
        info(f"  notes: {item.notes}")
        return 0
    asyncio.run(create_item(item))
    info(f"Created {item.category.value} '{item.title}' in {config.VAULT}")
    if public_key:
        info("Public key:")
        print(public_key)
    else:
        info(f"Reference: {item.reference}")
    return 0


# -------------------------------------------------------------- list-items

def add_list_items(sub: argparse._SubParsersAction) -> None:
    p = sub.add_parser(
        "list-items",
        help="list items in the vault with their category and target",
        description=(
            "List items in the vault with their category and target.\n\n"
            f"Lists the {config.VAULT} vault, sorted by title. Shows titles,\n"
            "categories and tags only, never secrets. Filters are case-insensitive."
        ),
        formatter_class=RAW,
    )
    p.add_argument("--service", help="only titles starting with <service>.")
    p.add_argument("--subsystem", help="only titles <service>.<subsystem>.*")
    p.add_argument("--category", help=f"only this category ({', '.join(naming.CATEGORY_NAMES)})")
    p.add_argument("--target", help="only items tagged target/<target>")
    p.add_argument("--archived", action="store_true", help="list archived items instead")
    p.add_argument("--json", action="store_true", help="print JSON instead of a table")
    p.set_defaults(func=cmd_list_items)


def item_rows(items: list, args: argparse.Namespace) -> list[dict[str, str]]:
    category = naming.parse_category(args.category) if args.category else None
    rows = []
    for item in items:
        parts = item.title.split(".")
        if args.service and parts[0].lower() != args.service.lower():
            continue
        if args.subsystem and (len(parts) < 2 or parts[1].lower() != args.subsystem.lower()):
            continue
        if category and item.category != category:
            continue
        target = naming.tag_value(item.tags, "target")
        if args.target and args.target.lower() not in target.lower().split(","):
            continue
        rows.append({
            "title": item.title,
            "category": getattr(item.category, "value", str(item.category)),
            "target": target,
            "updated": item.updated_at.date().isoformat(),
        })
    return sorted(rows, key=lambda r: r["title"].lower())


async def fetch_items(archived: bool) -> list:
    client = await vault.connect()
    vid = await vault.vault_id(client)
    return await vault.list_items(client, vid, archived)


def print_table(rows: list[dict[str, str]]) -> None:
    cols = ["title", "category", "target", "updated"]
    widths = {c: max([len(c)] + [len(r[c]) for r in rows]) for c in cols}
    print("  ".join(c.upper().ljust(widths[c]) for c in cols).rstrip())
    for r in rows:
        print("  ".join((r[c] or "-").ljust(widths[c]) for c in cols).rstrip())


def cmd_list_items(args: argparse.Namespace) -> int:
    if args.category:
        naming.parse_category(args.category)  # fail fast, before Touch ID
    rows = item_rows(asyncio.run(fetch_items(args.archived)), args)
    if args.json:
        print(json.dumps(rows, indent=2))
    elif rows:
        print_table(rows)
    else:
        info("No matching items.")
    return 0


# ----------------------------------------------------------- proxmox-token

def add_proxmox_token(sub: argparse._SubParsersAction) -> None:
    p = sub.add_parser(
        "proxmox-token",
        help="create the Terraform API token on a Proxmox node and store it",
        description=(
            "Create the Terraform API token on a Proxmox node and store it.\n\n"
            "Creates the terraform@pve user, TerraformProv role and API token on the node\n"
            "over SSH, and stores the token as the ApiCredentials item\n"
            "terraform.proxmox.<node>. The token goes straight into 1Password and is\n"
            f"never printed. Needs SSH as root to <node>.{config.HOME_DOMAIN}."
        ),
        formatter_class=RAW,
    )
    p.add_argument("node", help="node name, e.g. pve-01")
    p.set_defaults(func=cmd_proxmox_token)


def cmd_proxmox_token(args: argparse.Namespace) -> int:
    asyncio.run(proxmox.create_terraform_token(args.node))
    return 0


# -------------------------------------------------------------- completion

COMPLETION_EPILOG = """\
zsh: write it into a folder on $fpath once, and again after barn-op changes:
  mkdir -p ~/.zfunc && barn-op completion zsh > ~/.zfunc/_barn-op
  # in ~/.zshrc, before compinit:  fpath=(~/.zfunc $fpath)

bash: barn-op completion bash > ~/.local/share/bash-completion/completions/barn-op
"""


def add_completion(sub: argparse._SubParsersAction) -> None:
    p = sub.add_parser(
        "completion",
        help="print a shell completion script",
        description="Print a shell completion script for barn-op.\n"
        "It's generated from barn-op's options, so regenerate it after updating barn-op.",
        epilog=COMPLETION_EPILOG,
        formatter_class=RAW,
    )
    p.add_argument("shell", choices=["zsh", "bash"])
    p.set_defaults(func=cmd_completion)


def cmd_completion(args: argparse.Namespace) -> int:
    print(shtab.complete(parser(), shell=args.shell))
    return 0


# -------------------------------------------------------------------- main

def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="barn-op",
        description="Create and list 1Password items that follow docs/secrets.md "
        "(desktop app auth).",
    )
    sub = p.add_subparsers(dest="command", required=True, metavar="<command>")
    add_new_item(sub)
    add_list_items(sub)
    add_proxmox_token(sub)
    add_completion(sub)
    return p


def normalize(argv: list[str]) -> list[str]:
    """Make the category after `new-item` case-insensitive (Login, login, LOGIN)."""
    argv = list(argv)
    if "new-item" in argv:
        i = argv.index("new-item") + 1
        if i < len(argv) and not argv[i].startswith("-"):
            try:
                argv[i] = naming.parse_category(argv[i]).value.lower()
            except NamingError as e:
                print(f"barn-op new-item: error: {e}", file=sys.stderr)
                raise SystemExit(2) from e
    return argv


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(normalize(sys.argv[1:] if argv is None else argv))
    try:
        return args.func(args)
    except NamingError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130
