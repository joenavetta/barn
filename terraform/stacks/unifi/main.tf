# Switch/AP side of the VLAN design. OPNsense is the gateway, so every network
# here is VLAN-only (third_party_gateway): UniFi carries the tags, OPNsense
# routes, hands out DHCP, and enforces the firewall (stacks/opnsense).
# Management is the controller's built-in "Default" (untagged) network.

locals {
  net    = module.globals.networks
  tagged = { for k, n in local.net : k => n if !n.native && contains(var.networks_enabled, k) }
}

data "unifi_network" "mgmt" {
  name = "Default"
}

resource "unifi_network" "vlan" {
  for_each            = local.tagged
  name                = each.value.name
  vlan                = each.value.vlan
  third_party_gateway = true

  # Only OPNsense may answer DHCP on these VLANs.
  dhcp_guarding = {
    enabled = true
    servers = [each.value.gateway]
  }
}

locals {
  id = merge(
    { mgmt = data.unifi_network.mgmt.id },
    { for k, n in unifi_network.vlan : k => n.id },
  )
}

# ---- Port profiles -------------------------------------------------------
# Assign these to switch ports in the UI (or with unifi_device later).

locals {
  trunks = {
    # OPNsense LAN port: every VLAN.
    "Trunk: gateway" = ["trusted", "servers", "proxy", "iot", "cameras", "guest", "exitnode"]
    # pve-01 and pve-02 (vmbr0 VLAN-aware): host on Management, guests tagged.
    "Trunk: proxmox" = ["servers", "proxy", "iot", "exitnode"]
    # U7 APs: one SSID per VLAN.
    "Trunk: AP" = ["trusted", "iot", "guest"]
  }
  access = {
    "Access: trusted" = "trusted" # the 4 wired docks
    "Access: servers" = "servers" # Synology
    "Access: iot"     = "iot"     # HA Yellow, hubs
    "Access: cameras" = "cameras" # PoE cameras and doorbells
  }
}

locals {
  # Only networks that exist yet; skip profiles that would be empty.
  trunks_enabled = {
    for name, nets in local.trunks : name => [for k in nets : k if contains(keys(local.id), k)]
    if length([for k in nets : k if contains(keys(local.id), k)]) > 0
  }
  access_enabled = { for name, k in local.access : name => k if contains(keys(local.id), k) }
}

# The controller stores a custom trunk as "every network except these" and
# doesn't return tagged_networkconf_ids, so the trunk is described only by
# what it excludes. An empty exclusion list must be null, not [].
locals {
  trunk_excluded = {
    for name, nets in local.trunks_enabled : name => [
      for k, v in local.id : v if k != "mgmt" && !contains(nets, k)
    ]
  }
}

resource "unifi_port_profile" "trunk" {
  for_each                 = local.trunks_enabled
  name                     = each.key
  native_networkconf_id    = local.id.mgmt
  tagged_vlan_mgmt         = "custom"
  excluded_networkconf_ids = length(local.trunk_excluded[each.key]) > 0 ? local.trunk_excluded[each.key] : null
  poe_mode                 = "auto"
}

resource "unifi_port_profile" "access" {
  for_each              = local.access_enabled
  name                  = each.key
  native_networkconf_id = local.id[each.value]
  tagged_vlan_mgmt      = "block_all"
  poe_mode              = "auto"
}

# ---- Wi-Fi ---------------------------------------------------------------

data "unifi_ap_group" "default" {
  count = var.wlans_enabled ? 1 : 0
  name  = "All APs" # UniFi's default AP group; check the name before enabling SSIDs
}

data "unifi_client_qos_rate" "default" {
  count = var.wlans_enabled ? 1 : 0
  name  = "Default"
}

# SSIDs come later (var.wlans_enabled); the IoT devices so far are wired.
data "onepassword_item" "wifi" {
  for_each = var.wlans_enabled ? {
    main  = module.globals.onepassword.items.wifi_main
    iot   = module.globals.onepassword.items.wifi_iot
    guest = module.globals.onepassword.items.wifi_guest
  } : {}
  vault = module.globals.onepassword.vault
  title = each.value
}

locals {
  wlans = {
    main  = { ssid = "CHANGE-ME", network = "trusted", iot = false, guest = false }
    iot   = { ssid = "CHANGE-ME-iot", network = "iot", iot = true, guest = false }
    guest = { ssid = "CHANGE-ME-guest", network = "guest", iot = false, guest = true }
  }
}

resource "unifi_wlan" "this" {
  for_each      = var.wlans_enabled ? local.wlans : {}
  name          = each.value.ssid
  security      = "wpapsk"
  passphrase    = data.onepassword_item.wifi[each.key].password
  network_id    = local.id[each.value.network]
  user_group_id = data.unifi_client_qos_rate.default[0].id
  ap_group = {
    ids = [data.unifi_ap_group.default[0].id]
  }

  # IoT: WPA2 + 2.4 GHz-friendly settings for older devices.
  enhanced_iot = each.value.iot
  wpa3 = each.value.iot ? null : {
    support    = true
    transition = true
  }
  pmf_mode = each.value.iot ? "disabled" : "optional"

  # Guest: clients can't see each other.
  l2_isolation = each.value.guest
}
