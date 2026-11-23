"""Item titles, categories and tags, as documented in docs/secrets.md."""

from __future__ import annotations

import argparse
import re
from collections.abc import Sequence
from dataclasses import dataclass

from onepassword import ItemCategory

# The 1Password categories barn-op creates, by their SDK names.
CATEGORIES = (
    ItemCategory.LOGIN,
    ItemCategory.PASSWORD,
    ItemCategory.SSHKEY,
    ItemCategory.APICREDENTIALS,
)
CATEGORY_NAMES = tuple(c.value for c in CATEGORIES)  # Login, Password, SshKey, ApiCredentials

_SEGMENT = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


class NamingError(ValueError):
    pass


def parse_category(value: str) -> ItemCategory:
    """Match a category name case-insensitively, e.g. 'sshkey' -> SshKey."""
    for category in CATEGORIES:
        if value.lower() == category.value.lower():
            return category
    raise NamingError(
        f"unknown category '{value}' (expected one of: {', '.join(CATEGORY_NAMES)}; "
        "case doesn't matter)"
    )


def validate_segment(label: str, value: str) -> str:
    if not _SEGMENT.match(value):
        raise NamingError(
            f"{label} '{value}' must be lowercase letters/digits joined by '-' (e.g. pve-01)"
        )
    return value


@dataclass(frozen=True)
class ItemName:
    service: str
    subsystem: str
    name: str

    def __post_init__(self) -> None:
        validate_segment("service", self.service)
        validate_segment("subsystem", self.subsystem)
        validate_segment("name", self.name)

    @property
    def title(self) -> str:
        return f"{self.service}.{self.subsystem}.{self.name}"

    @classmethod
    def parse(cls, parts: str | Sequence[str]) -> "ItemName":
        """Accept 'service.subsystem.name' or ['service', 'subsystem', 'name'].

        Arguments are split on dots and the pieces joined, so any mix of the two
        forms works as long as it adds up to exactly three segments.
        """
        if isinstance(parts, str):
            parts = [parts]
        segments = [s for p in parts for s in p.split(".")]
        if len(segments) != 3 or not all(segments):
            given = " ".join(parts)
            raise NamingError(
                f"'{given}' isn't an item name: give <service>.<subsystem>.<name> "
                "or <service> <subsystem> <name>"
            )
        return cls(*segments)


ITEM_METAVAR = "<item>"


def add_item_argument(parser: argparse.ArgumentParser, example: str = "proxmox.smtp.notifications") -> None:
    """Positional 'item': one dotted argument or three separate ones.

    Turn it into an ItemName with ItemName.parse(args.item).
    """
    parser.add_argument(
        "item",
        nargs="+",
        metavar=ITEM_METAVAR,
        help=f"<service>.<subsystem>.<name>, dotted or as three words: {example} or {example.replace('.', ' ')}",
    )


def tags(service: str, subsystem: str, target: str) -> list[str]:
    validate_segment("target", target)
    return [f"service/{service}", f"subsystem/{subsystem}", f"target/{target}"]


def tag_value(item_tags: list[str], key: str) -> str:
    prefix = f"{key}/"
    return ",".join(t[len(prefix):] for t in item_tags if t.startswith(prefix))
