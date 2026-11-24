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

Not here yet: Kea, mDNS repeater (os-mdns-repeater: Trusted <-> IoT), the
Tailscale plugin settings (GUI only), DHCP ranges (the provider can't manage
them), and importing the hand-made Dnsmasq hosts.
