# Shared, non-secret values every stack reads with:
#   module "globals" { source = "../../modules/globals" }
# Change a value here once instead of in each stack.

output "zone" {
  description = "Public apex domain in Cloudflare"
  value       = "cowshed.cc"
}

output "internal_domain" {
  value = "home.cowshed.cc"
}

output "onepassword" {
  description = "Vault and item titles Terraform reads secrets from (naming: docs/secrets.md)"
  value = {
    vault = "Home Infrastructure"
    items = {
      proxmox_pve_01 = "terraform.proxmox.pve-01"
      proxmox_pve_02 = "terraform.proxmox.pve-02"
      cloudflare     = "terraform.cloudflare.default"
      unifi          = "terraform.unifi.default"
      opnsense       = "terraform.opnsense.default"
      tailscale      = "terraform.tailscale.default" # OAuth client: username = client ID, credential = secret
      wifi_home      = "unifi.wifi.home"
      wifi_iot       = "unifi.wifi.iot"
      wifi_guest     = "unifi.wifi.guest"
      wifi_cameras   = "unifi.wifi.cameras"
    }
  }
}

output "proxmox_nodes" {
  value = {
    pve-01 = { endpoint = "https://pve-01.home.cowshed.cc:8006/" }
    pve-02 = { endpoint = "https://pve-02.home.cowshed.cc:8006/" }
  }
}

# One /24 per VLAN: 10.42.<vlan>.0/24, gateway .1 on OPNsense. Management is
# the untagged (native) network on every trunk, which UniFi calls "Default".
# 10.42.x is unusual enough not to collide with the 192.168.x / 10.0.x LANs
# admins connect from when they use the subnet router away from home.
output "networks" {
  description = "VLANs: id, subnet, and whether the gateway lets them reach the internet"
  value = {
    mgmt     = { vlan = 1, name = "Management", cidr = "10.42.1.0/24", gateway = "10.42.1.1", internet = true, native = true }
    trusted  = { vlan = 20, name = "Trusted", cidr = "10.42.20.0/24", gateway = "10.42.20.1", internet = true, native = false }
    servers  = { vlan = 30, name = "Servers", cidr = "10.42.30.0/24", gateway = "10.42.30.1", internet = true, native = false }
    proxy    = { vlan = 35, name = "Proxy", cidr = "10.42.35.0/24", gateway = "10.42.35.1", internet = true, native = false }
    iot      = { vlan = 40, name = "IoT", cidr = "10.42.40.0/24", gateway = "10.42.40.1", internet = true, native = false }
    cameras  = { vlan = 50, name = "Cameras", cidr = "10.42.50.0/24", gateway = "10.42.50.1", internet = false, native = false }
    guest    = { vlan = 60, name = "Guest", cidr = "10.42.60.0/24", gateway = "10.42.60.1", internet = true, native = false }
    exitnode = { vlan = 70, name = "Exit", cidr = "10.42.70.0/24", gateway = "10.42.70.1", internet = true, native = false }
  }
}

# Static addresses (DHCP reservations on OPNsense, or static in the guest).
output "hosts" {
  value = {
    opnsense   = "10.42.1.1"
    switch-01  = "10.42.1.2" # UniFi core switch (Dnsmasq reservation on OPNsense)
    unifi      = "10.42.1.5" # UniFi OS Server VM on pve-01, kept in Management next to the devices it adopts
    pve-01     = "10.42.1.21"
    pve-02     = "10.42.1.22"
    synology   = "10.42.30.10"
    smtp       = "10.42.30.25"
    authentik  = "10.42.30.30"
    mealie     = "10.42.30.31" # Docker host
    immich     = "10.42.30.32"
    postgres   = "10.42.30.33"
    netbox     = "10.42.30.34"
    pbs        = "10.42.30.40"
    uptimekuma = "10.42.30.41"
    dns-01     = "10.42.30.53" # AdGuard + Unbound on pve-01
    dns-02     = "10.42.30.54" # AdGuard + Unbound on pve-02
    caddy      = "10.42.35.10" # reverse proxy, also tag:proxy on the tailnet
    homeassist = "10.42.40.10" # HA Yellow
    sensorpush = "10.42.40.11" # SensorPush gateway (wired)
    exit       = "10.42.70.10" # Tailscale exit node LXC
  }
}

# MAC addresses of devices that get their address from DHCP. A host listed
# here gets a Dnsmasq reservation from stacks/opnsense; leave it "" until known.
output "macs" {
  value = {
    homeassist = "d8:3a:dd:63:6d:03" # HA Yellow: Settings > System > Network, or the switch port in UniFi
    sensorpush = "20:c7:4f:04:32:78" # label on the gateway, or the switch port in UniFi
  }
}

# Apps family members reach through Caddy at <name>.home.cowshed.cc.
# backend/port are what Caddy proxies to (used for the Proxy -> Servers rule).
output "proxied_apps" {
  value = {
    mealie = { backend = "mealie", port = 9000 }
    immich = { backend = "immich", port = 2283 }
    auth   = { backend = "authentik", port = 9443 } # Authentik; must be reachable for OIDC logins
  }
}

output "ssh_public_keys" {
  value = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/1d/NYgXuTGtxXHGEJNRViZWOc209+tLTqIuYu7q5G"]
}
