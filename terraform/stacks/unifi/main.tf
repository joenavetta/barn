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
# One SSID per client network. Management, Servers and Cameras stay wired.
# Passphrases come from 1Password (unifi.wifi.<key>); names from var.ssids.
#
# Band steering moved from the SSID to the AP in UniFi Network 10, so it isn't
# set here. Keep it off on the APs: IoT devices that only do 2.4 GHz get
# confused when the AP pushes them to 5 GHz.

data "unifi_ap_group" "default" {
  count = var.wlans_enabled ? 1 : 0
  name  = "All APs" # UniFi's default AP group
}

data "unifi_client_qos_rate" "default" {
  count = var.wlans_enabled ? 1 : 0
  name  = "Default"
}

locals {
  wlans = {
    # Phones, laptops, tablets, all WPA3-capable, so WPA3 only: no offline
    # guessing from a captured handshake, no downgrade to WPA2, PMF required,
    # and 6 GHz needs WPA3 anyway. No 2.4 GHz: these clients all do 5 GHz, and
    # with band steering off they'd linger on 2.4 at the edge of range. The
    # printer is wired; anything WPA2-only belongs on IoT or Guest.
    home = {
      network = "trusted"
      bands   = ["5g", "6g"]
      wpa3    = true
      iot     = false
      isolate = false
    }
    # Smart plugs, speakers and other IoT. WPA2 only, and 2.4 GHz for the
    # devices that can't do 5 GHz. Not isolated: Home Assistant has to reach
    # these devices, and some of them talk to each other.
    # Wi-Fi cameras join this SSID too, with their own key (unifi.wifi.cameras)
    # that puts them on the Cameras VLAN: no internet, and no extra SSID.
    iot = {
      network = "iot"
      bands   = ["2g", "5g"]
      wpa3    = false
      iot     = true
      isolate = false
    }
    # Visitors. WPA2 for older phones; clients can't see each other, and
    # OPNsense lets the Guest VLAN reach only DNS and the internet.
    guest = {
      network = "guest"
      bands   = ["2g", "5g"]
      wpa3    = false
      iot     = false
      isolate = true
    }
  }

  wlans_enabled = var.wlans_enabled ? {
    for k, w in local.wlans : k => w if contains(keys(local.id), w.network)
  } : {}

  # Private pre-shared keys: extra passphrases on an SSID, each landing on
  # its own VLAN (item = unifi.wifi.<item>). Once an SSID has any, its normal
  # passphrase has to be listed too, on the SSID's own network.
  ppsk = [
    for p in [
      { wlan = "iot", item = "cameras", network = "cameras" },
    ] : p if contains(keys(local.wlans_enabled), p.wlan) && contains(keys(local.id), p.network)
  ]
}

data "onepassword_item" "wifi" {
  for_each = toset(concat(keys(local.wlans_enabled), [for p in local.ppsk : p.item]))
  vault    = module.globals.onepassword.vault
  title    = module.globals.onepassword.items["wifi_${each.key}"]
}

resource "unifi_wlan" "this" {
  for_each      = local.wlans_enabled
  name          = var.ssids[each.key]
  security      = "wpapsk"
  passphrase    = data.onepassword_item.wifi[each.key].password
  network_id    = local.id[each.value.network]
  user_group_id = data.unifi_client_qos_rate.default[0].id
  ap_group = {
    ids = [data.unifi_ap_group.default[0].id]
  }

  # The provider no longer defaults these on a new SSID, so set them.
  enabled    = true
  hide_ssid  = false
  is_guest   = false # UniFi's guest portal; isolation is done below and on OPNsense
  wlan_bands = each.value.bands

  wpa = {
    mode = "wpa2"
  }
  # wpa3 = true means WPA3 only (SAE, no WPA2 transition, PMF required).
  wpa3 = {
    support    = each.value.wpa3
    transition = false
  }
  # enhanced_iot forces WPA2, PMF off and DTIM 1 for older IoT radios.
  enhanced_iot = each.value.iot
  pmf_mode     = each.value.wpa3 ? "required" : (each.value.iot ? "disabled" : "optional")

  bss_transition = true # 802.11v roaming hints between the three APs
  l2_isolation   = each.value.isolate

  private_preshared_keys_enabled = length([for p in local.ppsk : p if p.wlan == each.key]) > 0
  private_preshared_keys = length([for p in local.ppsk : p if p.wlan == each.key]) > 0 ? concat(
    [{
      password   = data.onepassword_item.wifi[each.key].password
      network_id = local.id[each.value.network]
    }],
    [for p in local.ppsk : {
      password   = data.onepassword_item.wifi[p.item].password
      network_id = local.id[p.network]
    } if p.wlan == each.key],
  ) : null
}
