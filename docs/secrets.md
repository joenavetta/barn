# Secrets and 1Password naming

All credentials for this setup live in the **`Home Infrastructure`** vault (set in
[`config/barn.env`](../config/barn.env)). Nothing
secret is committed to this repo. Create items with [`barn-op new-item`](../bin/README.md) so the names, tags,
and notes stay consistent. barn reads with a read-only service account when one
is set up: [1password-service-account.md](1password-service-account.md).

## Item title

```
<service>.<subsystem>.<name>
```

All lowercase, words joined with `-`, segments joined with `.`. Slashes and
spaces are avoided so every item works in a secret reference like
`"op://Home Infrastructure/terraform.proxmox.pve-01/credential"`.

| Segment     | Meaning | Examples |
|-------------|---------|----------|
| `service`   | The local system that **uses or owns** the credential. Use `home` for things that span everything. | `proxmox`, `postfix`, `terraform`, `synology`, `immich`, `caddy`, `tailscale`, `home` |
| `subsystem` | The component of that service the credential is for. | `smtp`, `database`, `api`, `ssh`, `webui`, `acme`, `hyper-backup` |
| `name`      | A service-specific name: the instance, account, or purpose. Use `default` when there's only one. | `notifications`, `default`, `pve-01`, `root`, `relay` |

The item's 1Password category, the system it grants access to, and a
description go on the item itself rather than in the title.

## Categories

barn-op creates four 1Password categories, using the SDK's names. On the
command line they're case-insensitive (`login`, `Login` and `LOGIN` all work).

| Category         | Use for |
|------------------|---------|
| `Login`          | An account with a username and password: web UIs, local admin users, database users. Include the URL. |
| `Password`       | A secret with no username: encryption passphrases (PBS, Hyper Backup), Wi-Fi PSKs, recovery keys. |
| `SshKey`         | Key pairs (Ed25519 by default). Usable straight from the 1Password SSH agent. |
| `ApiCredentials` | API tokens and keys, SMTP tokens, Tailscale auth keys, B2 application keys. Secret in `credential`, key ID/user/SMTP login in `username`. |

If something doesn't fit, add the category to `CATEGORIES` in
`lib/python/src/barn/op/naming.py` and its fields in `vault.py`.

## Tags

Every item gets three tags, from the command line, so it can be filtered in
the app or with `barn-op list-items`:

| Tag | Meaning | Examples |
|-----|---------|----------|
| `service/<service>` | Title's first segment | `service/proxmox` |
| `subsystem/<subsystem>` | Title's second segment | `subsystem/smtp` |
| `target/<target>` | The system the credential **grants access to** | `target/proton`, `target/proxmox`, `target/backblaze` |

## Notes

The item's notes hold the `--description` given when it was created: one or two
sentences on what it is and where it's used.

### Examples

| Title | Category | Target | What it is |
|-------|----------|--------|------------|
| `proxmox.smtp.notifications` | ApiCredentials | proton | Proton SMTP token Proxmox uses for email notifications |
| `postfix.smtp.relay` | ApiCredentials | proton | Proton SMTP token the internal Postfix relay sends with |
| `terraform.proxmox.pve-01` | ApiCredentials | proxmox | Proxmox API token `terraform@pve!tf` on pve-01 |
| `terraform.proxmox.pve-02` | ApiCredentials | proxmox | Same, on pve-02 |
| `terraform.cloudflare.default` | ApiCredentials | cloudflare | Token Terraform uses for DNS |
| `terraform.opnsense.default` | ApiCredentials | opnsense | OPNsense API key/secret for Terraform |
| `terraform.unifi.default` | ApiCredentials | unifi | UniFi API key for Terraform |
| `terraform.ssh.pve-01` | SshKey | proxmox | Key the bpg provider uses for SSH-only operations on pve-01 |
| `home.ssh.admin` | SshKey | home | Joe's admin key, installed on every host and VM via cloud-init |
| `proxmox.webui.pve-01-root` | Login | proxmox | Proxmox root@pam on pve-01 |
| `caddy.acme.dns01` | ApiCredentials | cloudflare | DNS-edit-only token for the `*.home.cowshed.cc` certificate |
| `tailscale.auth.pve-01` | ApiCredentials | tailscale | Tailscale auth key used to join pve-01 |
| `pbs.encryption.default` | Password | pbs | Proxmox Backup Server client encryption passphrase |
| `synology.hyper-backup.encryption` | Password | synology | Hyper Backup client-side encryption password |
| `synology.hyper-backup.backblaze` | ApiCredentials | backblaze | Backblaze B2 application key for Hyper Backup |
| `immich.database.postgres` | Login | postgres | Immich database user |
| `opnsense.webui.root` | Login | opnsense | OPNsense web UI root account |
| `unifi.webui.admin` | Login | unifi | UniFi controller local admin |
| `unifi.wifi.home` | Password | unifi | Home SSID passphrase (Trusted VLAN) |
| `unifi.wifi.iot` | Password | unifi | IoT SSID passphrase (IoT VLAN) |
| `unifi.wifi.guest` | Password | unifi | Guest SSID passphrase (Guest VLAN) |
| `unifi.wifi.cameras` | Password | unifi | Cameras SSID passphrase (Cameras VLAN) |

## Rotation and cleanup

- Rotating: create the new credential, update the item in place (keep the
  title), then revoke the old one at the source. Cloudflare account tokens
  roll in one step with [`barn-cf rotate`](barn-cf.md).
- Retiring a system: archive its items (`barn-op list-items --service <service>`),
  don't delete them right away.
