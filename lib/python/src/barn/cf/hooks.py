"""Push hooks: where a rolled token has to go besides 1Password.

A hook runs after the new value is saved in 1Password. Items with no hook need
no push (Terraform reads terraform.cloudflare.dns from 1Password at plan time).

To wire up a consumer, write a function `(item_title, new_value) -> None` that
raises PushError on failure, and register it in HOOKS. Mark it ready=True once
it really pushes; a hook with ready=False is a stub, and barn-cf won't roll that
token unless you pass --skip-push (the old secret dies at the roll, so the
consumer would break until you update it by hand).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Callable

from barn.op import config

PushFn = Callable[[str, str], None]


class PushError(RuntimeError):
    pass


@dataclass(frozen=True)
class Hook:
    description: str
    push: PushFn
    ready: bool


# ------------------------------------------------------------------ caddy

CADDY_HOST = os.environ.get("BARN_CADDY_HOST", f"proxy.{config.HOME_DOMAIN}")


def push_caddy(item_title: str, new_value: str) -> None:
    """Stub until the Caddy proxy exists.

    Planned: over SSH to CADDY_HOST, write the token to the env file Caddy's
    systemd unit reads (e.g. /etc/caddy/cloudflare.env, mode 0600, value on
    stdin so it never appears in argv), then `systemctl reload caddy` and check
    it's active. Fill this in and set ready=True below when the host is built.
    """
    raise PushError(
        f"the Caddy push isn't built yet; put the new {item_title} value on "
        f"{CADDY_HOST} by hand and reload Caddy"
    )


HOOKS: dict[str, Hook] = {
    "caddy.acme.cloudflare": Hook(
        description=f"write to Caddy on {CADDY_HOST} and reload",
        push=push_caddy,
        ready=False,
    ),
}


def for_item(title: str) -> Hook | None:
    return HOOKS.get(title)
