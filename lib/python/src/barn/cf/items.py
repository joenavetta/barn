"""Read and write the 1Password items barn-cf works on.

A rotatable token is an ApiCredentials item (e.g. caddy.acme.cloudflare) with:
  credential   the token value (concealed)
  account id   Cloudflare account ID (text)
  token id     the token's ID, not its secret (text)
  last rotated set by barn-cf (text, UTC ISO time)
`barn-cf link` adds account id and token id to an item made with barn-op.
"""

from __future__ import annotations

from dataclasses import dataclass

from onepassword import Client, Item, ItemField, ItemFieldType

from barn.op import vault

SECRET = "credential"
ACCOUNT_ID = "account id"
TOKEN_ID = "token id"
LAST_ROTATED = "last rotated"


@dataclass
class TokenItem:
    item: Item

    @property
    def title(self) -> str:
        return self.item.title

    def get(self, title: str) -> str | None:
        f = _find(self.item, title)
        return f.value if f and f.value else None

    def require(self, title: str) -> str:
        value = self.get(title)
        if not value:
            raise SystemExit(
                f"error: '{self.title}' has no '{title}' field"
                + ("" if title == SECRET else
                   f"; run `barn-cf link {self.title} --account-id <id>` first")
            )
        return value

    def set(self, title: str, value: str, concealed: bool = False) -> None:
        f = _find(self.item, title)
        if f:
            f.value = value
            return
        type_ = ItemFieldType.CONCEALED if concealed else ItemFieldType.TEXT
        self.item.fields.append(
            ItemField(id=title.replace(" ", "_"), title=title, field_type=type_, value=value)
        )


def _find(item: Item, title: str) -> ItemField | None:
    for f in item.fields:
        if f.title.lower() == title or f.id.lower() == title.replace(" ", "_"):
            return f
    return None


async def load(client: Client, vid: str, title: str) -> TokenItem:
    matches = [i for i in await vault.list_items(client, vid) if i.title == title]
    if not matches:
        raise SystemExit(f"error: no item '{title}' in the vault")
    if len(matches) > 1:
        raise SystemExit(f"error: {len(matches)} items are named '{title}'; archive the extras")
    return TokenItem(await client.items.get(vid, matches[0].id))


async def save(client: Client, token_item: TokenItem) -> TokenItem:
    return TokenItem(await client.items.put(token_item.item))
