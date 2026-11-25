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

Passphrases are 1Password Password items `unifi.wifi.home`, `unifi.wifi.iot`
and `unifi.wifi.guest`. The IoT SSID also has a second, camera-only key
(`unifi.wifi.cameras`, a UniFi private pre-shared key) that puts a device on
the Cameras VLAN (50, no internet). The Reolink E1 Pros join with that key.

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
   barn-op new-item Password unifi.wifi.cameras --target unifi --description "Camera key on the IoT SSID (Cameras VLAN)" --prompt
   ```

2. Pick the SSID names in `var.ssids` (or `terraform.tfvars`).
3. `terraform plan`. It should add the Trusted, Guest and Cameras networks,
   the "Access: trusted" and "Access: cameras" profiles and three SSIDs, and update the trunk profiles to
   carry the new VLANs. It must not replace the IoT network. If the AP group
   isn't called "All APs", the plan fails on `data.unifi_ap_group`; fix the
   name in `main.tf`.
4. `terraform apply`, then check Settings > Networks lists Trusted and Guest
   with their VLAN IDs. If a port or SSID shows "20 (undefined)" or
   "60 (undefined)", open that network in the UI and click Save once.
5. On each AP (Devices > the AP > Settings), turn Band Steering off. It's set
   on the AP now, not the SSID.
6. Optional: give the AP switch ports the "Trunk: AP" profile, so they carry
   only Management, Trusted, IoT, Guest and Cameras instead of every VLAN.
