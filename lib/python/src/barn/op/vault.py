"""1Password SDK calls: desktop app auth, vault lookup, listing and creating items."""

from __future__ import annotations

from dataclasses import dataclass

from onepassword import (
    AutofillBehavior,
    Client,
    DesktopAuth,
    ItemCategory,
    ItemCreateParams,
    ItemField,
    ItemFieldType,
    ItemListFilterByState,
    ItemListFilterByStateInner,
    ItemOverview,
    PasswordRecipeRandom,
    PasswordRecipeRandomInner,
    Secrets,
    Website,
)

from barn.op import config

# Field the secret goes in, per category; also the op:// reference field name.
SECRET_FIELD = {
    ItemCategory.LOGIN: "password",
    ItemCategory.PASSWORD: "password",
    ItemCategory.SSHKEY: "private key",
    ItemCategory.APICREDENTIALS: "credential",
}


@dataclass
class NewItem:
    title: str
    category: ItemCategory
    tags: list[str]
    notes: str
    username: str | None = None
    secret: str | None = None  # password, token, or PEM private key
    url: str | None = None

    def fields(self) -> list[ItemField]:
        c = self.category
        if c == ItemCategory.SSHKEY:
            return [_field("private_key", "private key", ItemFieldType.SSHKEY, self.secret)]
        out = []
        if self.username or c == ItemCategory.LOGIN:
            out.append(_field("username", "username", ItemFieldType.TEXT, self.username or ""))
        if c == ItemCategory.APICREDENTIALS:
            out.append(_field("credential", "credential", ItemFieldType.CONCEALED, self.secret))
        else:
            out.append(_field("password", "password", ItemFieldType.CONCEALED, self.secret))
        return out

    @property
    def reference(self) -> str:
        field = "public key" if self.category == ItemCategory.SSHKEY else SECRET_FIELD[self.category]
        return f"op://{config.VAULT}/{self.title}/{field}"


def _field(id_: str, title: str, type_: ItemFieldType, value: str | None) -> ItemField:
    if value is None:
        raise ValueError(f"missing value for field {id_}")
    return ItemField(id=id_, title=title, field_type=type_, value=value)


def generate_password(length: int) -> str:
    recipe = PasswordRecipeRandom(
        parameters=PasswordRecipeRandomInner(
            include_digits=True, include_symbols=True, length=length
        )
    )
    return Secrets.generate_password(recipe).password


async def connect() -> Client:
    """Authenticate through the desktop app (Touch ID prompt)."""
    try:
        return await Client.authenticate(
            auth=DesktopAuth(account_name=config.ACCOUNT),
            integration_name=config.INTEGRATION_NAME,
            integration_version=config.INTEGRATION_VERSION,
        )
    except FileNotFoundError as e:
        raise SystemExit(f"error: {e} (barn-op needs the 1Password desktop app)") from e
    except Exception as e:
        raise SystemExit(
            f"error: can't connect to 1Password ({e}). Is the app unlocked, with "
            "Settings > Developer > 'Integrate with other apps' turned on, and is "
            f"BARN_OP_ACCOUNT ({config.ACCOUNT}) the account name shown in the app's sidebar?"
        ) from e


async def vault_id(client: Client, name: str = config.VAULT) -> str:
    for vault in await client.vaults.list():
        if vault.title == name:
            return vault.id
    raise SystemExit(f"error: vault '{name}' not found")


async def list_items(client: Client, vid: str, archived: bool = False) -> list[ItemOverview]:
    """Active items, or archived ones when archived=True."""
    state = ItemListFilterByState(
        content=ItemListFilterByStateInner(active=not archived, archived=archived)
    )
    return await client.items.list(vid, state)


async def item_exists(client: Client, vid: str, title: str) -> bool:
    return any(item.title == title for item in await client.items.list(vid))


async def create(client: Client, vid: str, item: NewItem) -> None:
    websites = (
        [Website(url=item.url, label="website", autofill_behavior=AutofillBehavior.NEVER)]
        if item.url
        else None
    )
    await client.items.create(
        ItemCreateParams(
            category=item.category,
            vault_id=vid,
            title=item.title,
            fields=item.fields(),
            tags=item.tags,
            notes=item.notes,
            websites=websites,
        )
    )
