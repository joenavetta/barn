"""Read secrets without putting them in argv or on screen."""

from __future__ import annotations

import getpass
import sys


def read_secret(prompt: str) -> str:
    """From stdin when piped, otherwise a hidden prompt asked twice."""
    if not sys.stdin.isatty():
        value = sys.stdin.read().rstrip("\r\n")
    else:
        value = getpass.getpass(f"{prompt}: ")
        if getpass.getpass("Confirm: ") != value:
            raise SystemExit("error: values don't match")
    if not value:
        raise SystemExit("error: empty secret")
    return value
