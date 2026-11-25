# bin

Commands for this repo, flat in one folder and named `barn-<type>`, so the
folder can go on `PATH` and every command works from any directory. Commands
with sub-commands are thin shell wrappers around Python code in
[`../lib/python/`](../lib/python/), run with [uv](https://docs.astral.sh/uv/)
(the first run creates the virtualenv).

```bash
export PATH="$HOME/src/github.com/joenavetta/barn/bin:$PATH"   # e.g. in ~/.zshrc
```

| Command | What it does |
|---------|--------------|
| `barn-cf rotate <item> [--dry-run] [--skip-push]` | Roll a Cloudflare account API token (same token and permissions, new secret; the old one dies at once), save it to the 1Password item, and push it to its consumer. See [docs/barn-cf.md](../docs/barn-cf.md). |
| `barn-cf link <item> --account-id ID` / `barn-cf show <item>` | Record a token's account ID and token ID on its item (once); show its name, status and last rotation. |
| `barn-op new-item <category> <service>.<subsystem>.<name> --target T --description "..."` | Create a 1Password item following [docs/secrets.md](../docs/secrets.md). The name can also be three words (`proxmox smtp notifications`); this works for every barn-op and barn-cf command that takes an item. Category is `Login`, `Password`, `SshKey` or `ApiCredentials` (any case), and each has its own options: `barn-op new-item login --help`. `--dry-run` shows what it would create. |
| `barn-op list-items [--service S] [--subsystem S] [--category C] [--target T] [--json]` | List items in the vault with their category and target (titles and tags only, no secrets). |
| `barn-op proxmox-token <node>` | Create the Terraform user, role, and token on a Proxmox node over SSH and store it as `terraform.proxmox.<node>`. |
| `barn-op completion {zsh,bash}` | Print a shell completion script (see below). |
| `barn-tf <terraform args>` | Run `terraform` with the 1Password provider's credentials set (service account token, or the desktop app). Use it instead of `terraform` in a stack dir: `barn-tf plan`. |
| `barn-pve-cloud-template` | Build a cloud-init VM template. Plain bash; copy it to the Proxmox node and run it there. |

`barn-op` and `barn-cf` use the [1Password Python SDK](https://github.com/1Password/onepassword-sdk-python).
If a 1Password service account token is set up (in the macOS Keychain, see
[docs/1password-service-account.md](../docs/1password-service-account.md)),
they use it and there's no prompt. Otherwise they use desktop app auth and
each run gets a Touch ID prompt; turn on **Settings > Developer > Integrate
with other apps** in the 1Password app for that. `BARN_OP_AUTH` picks between
them (`auto`, `service-account`, `desktop`).
Defaults (vault, account, auth, domain) are in
[`config/barn.env`](../config/barn.env). The launchers load that file with
`lib/shell/barn-env.sh`, and any variable already set in your shell wins, e.g.
`BARN_OP_VAULT=Scratch barn-op list-items`. Secrets are never taken as command-line arguments: SSH keys and
passwords are generated locally and sent straight to 1Password, and tokens
you paste are read from stdin or a hidden prompt.

```bash
barn-op --help
barn-op new-item SshKey home ssh admin --target home --description "Joe's admin key for all hosts"
pbpaste | barn-op new-item ApiCredentials proxmox smtp notifications --target proton \
    --username notifications@cowshed.cc --description "Proxmox notification email"
barn-op proxmox-token pve-01
barn-op list-items --target proton
```

## Shell completion

`barn-op` completion is a static script generated from its options, so Tab
is instant. Set it up once for zsh:

```bash
mkdir -p ~/.zfunc && barn-op completion zsh > ~/.zfunc/_barn-op
# in ~/.zshrc, before compinit runs:
fpath=(~/.zfunc $fpath)
```

Re-run the first line after pulling changes that add or rename options.
Categories complete in lowercase (`login`, `sshkey`, ...); any case still works
when typed.
