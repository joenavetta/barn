# opnsense

VLAN devices, firewall aliases, inter-VLAN rules and Dnsmasq DHCP reservations
on OPNsense, which routes between all VLANs. Uses
[`browningluke/opnsense`](https://registry.terraform.io/providers/browningluke/opnsense/latest).
The VLAN table and firewall matrix live in the plan doc (Network design).

VLANs move over one at a time. `networks_enabled` lists the VLAN devices that
exist (IoT first), and rules apply only to interfaces listed in `interfaces`.
Management (`lan`) stays out of `interfaces` until the cutover, so OPNsense's
default "LAN to any" rule keeps admin access to every VLAN until then.

## First apply: IoT (VLAN 40)

1. Create an OPNsense API user (System > Access > Users, with an API key) and
   store the key and secret in 1Password as `terraform.opnsense.default`, an
   API Credential (username = key, credential = secret).
2. Check `trunk_parent` is the NIC switch-01 plugs into (Interfaces >
   Assignments shows which `igcN` is LAN). Fill in the MACs of the IoT devices
   in `modules/globals` `macs`.
3. `terraform init -backend-config=../../backend.hcl && terraform apply`.
   This creates `vlan0.40`, the aliases and the Dnsmasq reservations. No rules yet.
4. In the GUI (the API can't do these):
   - Interfaces > Assignments: add `vlan0.40`, then enable it as "IoT" with
     static IPv4 10.42.40.1/24.
   - Services > Dnsmasq DNS & DHCP > General: add IoT to Interfaces.
   - Dnsmasq > DHCP ranges: IoT, 10.42.40.100 to 10.42.40.199.
5. Put the identifier IoT got (`optN`) in `interfaces` (`iot = "optN"`) and
   apply again. That adds the IoT rules: DNS on the gateway, internet, and a
   logged block for everything else, including the other home networks.
6. Check that Firewall > Rules > IoT has the automatic DHCP allow rule. If it
   doesn't, devices on IoT won't get an address.

## Second apply: Trusted (VLAN 20) and Guest (VLAN 60)

Do this before the UniFi stack, so the Home and Guest SSIDs have DHCP
when they come up.

1. `terraform apply`. `networks_enabled` now lists `trusted` and `guest`, so
   this creates `vlan0.20` and `vlan0.60`. No rules yet.
2. In the GUI:
   - Interfaces > Assignments: add `vlan0.20` as "Trusted" with static IPv4
     10.42.20.1/24, and `vlan0.60` as "Guest" with 10.42.60.1/24. Enable both.
   - Services > Dnsmasq DNS & DHCP > General: add Trusted and Guest to
     Interfaces.
   - Dnsmasq > DHCP ranges: Trusted 10.42.20.100 to 10.42.20.199, and Guest
     10.42.60.100 to 10.42.60.199 (a shorter lease, like 4h, suits guests).
3. Uncomment `trusted` and `guest` in `interfaces` with the identifiers they
   got (`optN`), and apply again. Check the plan only adds rules on those two
   interfaces:
   - Trusted: DNS on the gateway, the reverse proxy, IoT, internet, admin
     devices to Management/Servers/Cameras, then a logged block.
   - Guest: DNS on the gateway, internet, then a logged block. Guests can't
     reach any home network.
4. Check that Firewall > Rules > Trusted and Guest have the automatic DHCP
   allow rule.

`admin_devices` is still empty, so no phone or laptop on Trusted can reach
Management yet. Admin work stays on a wired Management port (or Tailscale)
until those devices get reservations.

Not here yet: Kea, mDNS repeater (os-mdns-repeater: Trusted <-> IoT), the
Tailscale plugin settings (GUI only), DHCP ranges (the provider can't manage
them), and importing the hand-made Dnsmasq hosts.
