# 1Password service account

barn reads secrets from 1Password with a **read-only service account token**
when one is set up, instead of the desktop app. That stops the Touch ID prompt
on every `terraform plan` or `barn-op list-items`, which matters most when
Claude or a script runs many commands in a row.

The token can only read. Anything that creates or changes items still goes
through the 1Password app with Touch ID, or you do it by hand in the app.

| Who | With a token | Without one |
|-----|--------------|-------------|
| Terraform (`onepassword_item` data sources) | token | desktop app (Touch ID) |
| `barn-op list-items`, `barn-cf show` | token | desktop app |
| `barn-op new-item`, `barn-op proxmox-token`, `barn-cf rotate`, `barn-cf link` | **always the desktop app**: they write | desktop app |

For `barn-op` and `barn-cf`, `BARN_OP_AUTH` (in `config/barn.env`) can change
this: `auto` (default) as above, `service-account` to fail rather than prompt
when there's no token, `desktop` to ignore the token (handy when it has
expired).

## Creating it

On 1Password.com (**Developer > Directory > Service Accounts**, then **Create
a Service Account**) or with the `op` CLI, which signs in through the desktop
app:

```bash
op service-account create "barn" \
  --vault "Home Infrastructure:read_items" \
  --expires-in 7d
```

Give it **`Home Infrastructure` only, read items only**. Pick an expiry that
suits you (`--expires-in` takes values like `24h`, `7d`, `30d`).

The token (`ops_...`) is shown **once**. Copy it, then store it in the login
Keychain. `-w` with no value makes `security` prompt for it, so the token
doesn't land in your shell history:

```bash
security add-generic-password -U -a "$USER" -s barn.op.service-account -w
# paste the token at both prompts
```

`-U` replaces an existing item, so the same command stores a new token later.
While you're logged in to the Mac the login keychain is unlocked, and reads by
the `security` tool don't prompt.

Things to know about service accounts:

- They can't be given access to your Private/Personal vault, so everything barn
  reads has to be in `Home Infrastructure`.
- Vaults and permissions are fixed when the account is created. To change
  them, create a new service account.
- They see only the vaults they were granted. If the token works but barn says
  the vault isn't found, the account wasn't given `Home Infrastructure`.
- 1Password rate-limits service accounts by the hour and day. barn makes a
  handful of calls per command, so this only matters for loops.

## Using it

### barn-op and barn-cf

Nothing to do. The launchers in `bin/` read the token from the Keychain (or
from `OP_SERVICE_ACCOUNT_TOKEN`, if your shell already has it) and pass it only
to the command they run. Check it with:

```bash
BARN_OP_AUTH=service-account barn-op list-items
```

### Terraform

Terraform runs on its own; there's no wrapper. The `onepassword` provider
blocks are empty, so the provider takes its credentials from the environment,
and it refuses to start if **both** `OP_SERVICE_ACCOUNT_TOKEN` and
`OP_ACCOUNT` are set. [`lib/shell/op-env.sh`](../lib/shell/op-env.sh) exports
exactly one: the Keychain token if there is one, else `OP_ACCOUNT` (the
account ID) for the desktop app. Source it from `~/.zshrc`:

```bash
. "$HOME/src/github.com/joenavetta/barn/lib/shell/op-env.sh"
```

Then `terraform plan` works as usual in any stack. Any `op` CLI command in
that shell also uses the token.

This puts the token in every new shell's environment, including shells that
Claude runs. That is the point (no prompts), and the token is read-only and
short-lived. If you'd rather not, skip the `~/.zshrc` line and source the
file only in the terminal where you run Terraform.

## When it expires

barn-op and barn-cf stop with "can't sign in to 1Password with the service
account token", and Terraform's provider fails to authenticate. Create a new
token (or a new service account), run the `security add-generic-password -U
...` command again, and open a new shell (or re-source `op-env.sh` after
`unset OP_SERVICE_ACCOUNT_TOKEN`). Until then, `BARN_OP_AUTH=desktop` gets
barn-op working with Touch ID, and for Terraform:

```bash
unset OP_SERVICE_ACCOUNT_TOKEN; export OP_ACCOUNT=PW5WK2EEO5HM5L4UG46ABS37TA
```

To revoke it early, delete the service account on 1Password.com and remove the
Keychain item:

```bash
security delete-generic-password -s barn.op.service-account
```
