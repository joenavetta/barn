# TODO

Open follow-ups for barn and the network upgrade. Add an item when something
is deferred; delete it in the PR that finishes it.

## Proxmox

- [ ] **Let's Encrypt certs for pve-01 and pve-02.** Use ACME through Terraform
  with the bpg resources `proxmox_virtual_environment_acme_account`,
  `proxmox_virtual_environment_acme_dns_plugin` and
  `proxmox_virtual_environment_acme_certificate`, and Cloudflare DNS-01. One
  account covers both nodes, and Proxmox renews the certs itself. Then remove
  the temporary `insecure = true` from `terraform/stacks/pve-01/providers.tf`
  (see the stack README).
  - Decide: the Let's Encrypt contact email.
  - Decide: the Cloudflare token. A new DNS-edit-only token for cowshed.cc,
    e.g. `proxmox.acme.cloudflare`, is the suggestion.

## Terraform globals

- [ ] **Land the network globals** (`networks`, `hosts`, `proxied_apps`) from
  the network draft. Then switch `terraform/stacks/pve-01/main.tf` from its
  local Management IPs to `module.globals.networks` / `hosts`. The draft
  already names the switch `switch-01` (10.42.1.2).
- [ ] **Cloudflare item name mismatch.** Globals reads
  `terraform.cloudflare.default`, but the vault item is
  `terraform.cloudflare.dns`. Rename one of them before running the
  cloudflare stack. `docs/secrets.md` has the same old names
  (`terraform.cloudflare.default`, `caddy.acme.dns01`).

## UniFi

- [ ] **`unifi` stack.** Create the `terraform.unifi.default` API key on the
  UniFi OS Server (https://unifi.home.cowshed.cc:11443), then build
  `terraform/stacks/unifi` (networks, port profiles, SSIDs) from the network
  draft.
