# unifi

VLANs, port profiles, and SSIDs on the UniFi OS Server
(https://unifi.home.cowshed.cc:11443) via
[`ubiquiti-community/unifi`](https://registry.terraform.io/providers/ubiquiti-community/unifi/latest).
OPNsense is the gateway, so the networks are VLAN-only. Routing, DHCP and
firewall rules are in `stacks/opnsense`.

Networks move over one at a time: `networks_enabled` should match the same
variable in `stacks/opnsense`. Each SSID is created once its network is
enabled:

| SSID (`var.ssids`) | Network | Security | Bands | Notes |
|---|---|---|---|---|
| Home (`cowshed`) | Trusted, VLAN 20 | WPA3 only, PMF required | 5, 6 GHz | No 2.4 GHz; WPA2-only devices use IoT or Guest |
| IoT (`cowshed-iot`) | IoT, VLAN 40 | WPA2 | 2.4, 5 GHz | Enhanced IoT on, not isolated so HA can reach devices |
| Guest (`cowshed-guest`) | Guest, VLAN 60 | WPA2 | 2.4, 5 GHz | Client isolation; OPNsense allows only DNS and internet |
| Cameras (`cowshed-cameras`) | Cameras, VLAN 50 | WPA2 | 2.4, 5 GHz | Wi-Fi cameras; client isolation, no internet |

Passphrases are 1Password Password items `unifi.wifi.home`, `unifi.wifi.iot`,
`unifi.wifi.guest` and `unifi.wifi.cameras`.

Trunk profiles that carry every network are "Allow All". UniFi adds each new
network to the exclusions of every custom trunk, so a custom profile with an
empty exclusion list would silently stop carrying new VLANs.

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

## Second apply: Trusted, Guest and the SSIDs

Run the opnsense stack's "Second apply" first, so Trusted and Guest have
DHCP before anything joins them.

1. Create the passphrases. `--prompt` lets you type one that's easy to enter
   on a TV or a smart plug. Without it you get 32 random characters with
   symbols, which some IoT devices reject.

   ```
   barn-op new-item Password unifi.wifi.home  --target unifi --description "Home SSID (Trusted VLAN)" --prompt
   barn-op new-item Password unifi.wifi.iot   --target unifi --description "IoT SSID (IoT VLAN)" --prompt
   barn-op new-item Password unifi.wifi.guest --target unifi --description "Guest SSID (Guest VLAN)" --prompt
   barn-op new-item Password unifi.wifi.cameras --target unifi --description "Cameras SSID (Cameras VLAN)" --prompt
   ```

2. Pick the SSID names in `var.ssids` (or `terraform.tfvars`).
3. `terraform plan`. It should add the Trusted, Guest and Cameras networks,
   the "Access: trusted" and "Access: cameras" profiles and four SSIDs, and update the trunk profiles to
   carry the new VLANs. It must not replace the IoT network. If the AP group
   isn't called "All APs", the plan fails on `data.unifi_ap_group`; fix the
   name in `main.tf`.
4. `terraform apply`, then check Settings > Networks lists Trusted and Guest
   with their VLAN IDs. If a port or SSID shows "20 (undefined)" or
   "60 (undefined)", open that network in the UI and click Save once.
5. Join each SSID and check the address: cowshed 10.42.20.x, cowshed-iot
   10.42.40.x, cowshed-guest 10.42.60.x, cowshed-cameras 10.42.50.x. If they
   get 169.254.x, Dnsmasq on OPNsense needs an Apply (see stacks/opnsense).

## APs and switch ports (devices.tf)

The three APs and the switch-01 ports are imported by MAC on the first plan
(import blocks in `devices.tf`), so Terraform takes them over without
re-adopting anything. It sets band steering off on each AP, names them
ap-01..03, and assigns the port profiles:

| Port | Device | Profile |
|---|---|---|
| 1 | OPNsense (igc0) | Trunk: gateway |
| 2 | pve-02 | Trunk: proxmox |
| 4 | pve-01 | Trunk: proxmox |
| 7 | SensorPush | Access: iot |
| 8 | Home Assistant | Access: iot |
| 20-22 | ap-01..03 | Trunk: AP |

Other ports keep the switch default. When a device moves to another port,
change `switch_01_ports` to match. Check the plan imports 3 devices and 8
ports and only changes names, band steering and port profiles.
