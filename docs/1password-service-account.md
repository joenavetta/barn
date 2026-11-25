# 1Password service account

barn's commands (`barn-op`, `barn-cf`, and Terraform through `barn-tf`) can
sign in to 1Password with a **service account token** instead of the desktop
app. That stops the Touch ID prompt on every run, which matters most when
Claude or a script is running many commands in a row.

| `BARN_OP_AUTH` | Behavior |
|----------------|----------|
| `auto` (default, in `config/barn.env`) | Use the token if there is one; otherwise the 1Password app with Touch ID. |
| `service-account` | Require the token. Fails rather than prompting, which is useful for unattended runs. |
| `desktop` | Ignore any token and use the 1Password app. Handy when the token has expired. |

The token is looked up in this order:

1. `OP_SERVICE_ACCOUNT_TOKEN`, if it's already set in your environment.
2. The macOS Keychain generic password with service name
   `$BARN_OP_KEYCHAIN_SERVICE` (default `barn.op.service-account`), read with
   `security find-generic-password`.

The launchers in `bin/` export the token only to the command they run, so it
never ends up in your interactive shell. Don't put it in `~/.zshrc` or a file
in the repo.

## What the service account needs

Grant it access to **`Home Infrastructure` only**, with **read and write**:

| Command | Needs |
|---------|-------|
| `barn-op list-items`, `barn-cf show` | read |
| `barn-op new-item`, `barn-op proxmox-token` | **write**: they create items |
| `barn-cf rotate`, `barn-cf link` | **write**: they update items in place |
| Terraform (`onepassword_item` data sources) | read |

With read-only access, `barn-op new-item` fails when it tries to create the
item. If you'd rather keep the everyday token read-only, run the write
commands with `BARN_OP_AUTH=desktop` (Touch ID) instead.

Things to know about service accounts:

- They can't be given access to your Private/Personal vault, so every item barn
  uses has to be in `Home Infrastructure`.
- The vaults and permissions are set when the account is created. To change
  them, create a new service account.
- They see only the vaults they were granted. If the token works but barn says
  the vault isn't found, the account wasn't given `Home Infrastructure`.
- 1Password rate-limits service accounts by the hour and day. barn's commands
  make a handful of calls each, so this only matters for loops.

## Creating it

Either on 1Password.com (**Developer > Directory > Service Accounts**, then
**Create a Service Account**) or with the `op` CLI, which signs in through the
desktop app:

```bash
op service-account create "barn" \
  --vault "Home Infrastructure:read_items,write_items" \
  --expires-in 7d
```

Pick an expiry that suits you (`--expires-in` takes values like `24h`, `7d`,
`30d`). The token (`ops_...`) is shown **once**. Copy it, then store it in the
login Keychain. `-w` with no value makes `security` prompt for it, so the token
doesn't land in your shell history:

```bash
security add-generic-password -U -a "$USER" -s barn.op.service-account -w
# paste the token at both prompts
```

`-U` replaces an existing item, so the same command rotates the token. While
you're logged in to the Mac, the login keychain is unlocked and reads by the
`security` tool don't prompt.

Check that it works:

```bash
BARN_OP_AUTH=service-account barn-op list-items
```

## Rotating and revoking

When the token expires, barn stops with "can't sign in to 1Password with the
service account token". Create a new token (or a new service account) and run
the `security add-generic-password -U ...` command again. Until then,
`BARN_OP_AUTH=desktop` falls back to Touch ID.

To revoke it early, delete the service account on 1Password.com and remove the
Keychain item:

```bash
security delete-generic-password -s barn.op.service-account
```

## Terraform

The `onepassword` provider reads its credentials from the environment, and it
refuses to start if both `OP_SERVICE_ACCOUNT_TOKEN` and `OP_ACCOUNT` are set.
So the stacks' `provider "onepassword" {}` blocks are empty, and you run
Terraform as `barn-tf` (same arguments as `terraform`). It sets exactly one:

- the service account token, when there is one, or
- `OP_ACCOUNT=$BARN_OP_ACCOUNT_ID` (desktop app, Touch ID) otherwise.

```bash
cd terraform/stacks/unifi
barn-tf plan
```

Plain `terraform` still works if you export one of those variables yourself.
