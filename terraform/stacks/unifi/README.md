# unifi

VLANs, port profiles, and SSIDs on the UniFi OS Server
(https://unifi.home.cowshed.cc:11443) via
[`ubiquiti-community/unifi`](https://registry.terraform.io/providers/ubiquiti-community/unifi/latest).
OPNsense is the gateway, so the networks are VLAN-only. Routing, DHCP and
firewall rules are in `stacks/opnsense`.

Networks move over one at a time: `networks_enabled` (IoT first) should match
the same variable in `stacks/opnsense`. SSIDs are off (`wlans_enabled = false`)
until there's a wireless device that needs one.

## First apply: IoT (VLAN 40)

1. In the UniFi Network app, open **Integrations** (its own item in the left
   sidebar on UniFi OS Server, not under Settings) and create an API key.
   Store it in 1Password as `terraform.unifi.default`, an API Credential with
   the key in `credential`.
2. `terraform init -backend-config=../../backend.hcl && terraform apply`.
   This creates the VLAN-only "IoT" network (VLAN 40, DHCP guarding so only
   OPNsense answers) and the "Access: iot" and trunk port profiles.
3. In UniFi Devices > switch-01 > Ports, give the Home Assistant and
   SensorPush ports the "Access: iot" profile. The uplink to OPNsense keeps
   the default profile, which already carries every VLAN tagged.

Port profiles are created but not assigned. Assign them per port in the UI.
