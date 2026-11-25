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

- [ ] **Cloudflare item name mismatch.** Globals reads
  `terraform.cloudflare.default`, but the vault item is
  `terraform.cloudflare.dns`. Rename one of them before running the
  cloudflare stack. `docs/secrets.md` has the same old names
  (`terraform.cloudflare.default`, `caddy.acme.dns01`).

## OPNsense DNS and DHCP

- [ ] **Static entries in Terraform.** Add a MAC (for DHCP devices) to each
  entry in the globals `hosts` map. The opnsense stack then creates one
  `opnsense_dnsmasq_host` per host. With a MAC it's a DHCP reservation, and
  without one it's a DNS name only. Import the entries made by hand
  (switch-01, pve-01, pve-02, unifi) rather than recreating them. Optionally
  manage the Unbound forward (`home.cowshed.cc` to 10.42.1.1:53053) with
  `opnsense_unbound_forward`. The provider can't manage Dnsmasq DHCP ranges,
  so those stay manual.

## UniFi and Wi-Fi

- [ ] **Admin devices on Trusted.** Give Joe's phone and laptop Dnsmasq
  reservations on Trusted and list them in the opnsense `admin_devices`
  variable, so they can reach Management and Servers from Wi-Fi.
- [ ] **mDNS between Trusted and IoT.** AirPlay, casting and HomeKit discovery
  need an mDNS repeater (os-mdns-repeater) on OPNsense for Trusted and IoT.
  The firewall already allows Trusted to IoT.
- [ ] **AP settings in Terraform.** Band steering off (per AP since UniFi
  Network 10) and the "Trunk: AP" port profile on the AP switch ports, with
  `unifi_device` / `unifi_device_port`. Both are manual for now.
- [ ] **UniFi "Default" network subnet.** It still says 192.168.1.0/24.
  OPNsense serves Management (10.42.1.0/24), so it's cosmetic, but set it to
  10.42.1.0/24 (gateway 10.42.1.1) so UniFi's client list matches, ideally
  through Terraform.
- [ ] **Unused switch ports.** Add a "Disabled" port profile for spare ports,
  and make Trusted, not Management, the native network on ordinary ports.
