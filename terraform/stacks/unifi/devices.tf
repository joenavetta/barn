# Adopted UniFi devices. Terraform can't adopt a device, only take over one the
# controller already has, so each device is imported by MAC first (the import
# blocks below). Attributes left out keep the controller's values.

locals {
  switch_01_mac = "74:fa:29:94:26:3c" # USW Pro Max 24 PoE, 10.42.1.2

  # Rename to where each AP hangs if you like; the key is only the address.
  aps = {
    ap-01 = { mac = "90:41:b2:02:5a:69", model = "U7 Lite" }
    ap-02 = { mac = "cc:35:d9:d6:dd:bc", model = "U7 Pro XG" }
    ap-03 = { mac = "cc:35:d9:d8:2c:38", model = "U7 Pro XG" }
  }

  # switch-01 ports that carry something other than the switch default.
  # Ports not listed (Joe's Mac on 3, the spares) keep the default: native
  # Management with every VLAN tagged. Only ports that already have an
  # override on the controller (7 and 8) can be imported; the rest are
  # created as new overrides.
  switch_01_ports = {
    1  = { name = "opnsense", profile = "Trunk: gateway" }
    2  = { name = "pve-02", profile = "Trunk: proxmox" }
    4  = { name = "pve-01", profile = "Trunk: proxmox" }
    7  = { name = "sensorpush", profile = "Access: iot" }
    8  = { name = "homeassist", profile = "Access: iot" }
    20 = { name = "ap-01", profile = "Trunk: AP" }
    21 = { name = "ap-02", profile = "Trunk: AP" }
    22 = { name = "ap-03", profile = "Trunk: AP" }
  }

  port_profile_id = merge(
    { for k, p in unifi_port_profile.trunk : k => p.id },
    { for k, p in unifi_port_profile.access : k => p.id },
  )
}

# ---- Access points ---------------------------------------------------------

import {
  for_each = local.aps
  to       = unifi_device.ap[each.key]
  id       = each.value.mac
}

resource "unifi_device" "ap" {
  for_each = local.aps
  mac      = each.value.mac
  name     = each.key

  # Band steering is per AP since UniFi Network 10. Off, because it pushes
  # dual-band IoT devices and the Wi-Fi cameras off 2.4 GHz, which breaks
  # pairing and costs range. cowshed has no 2.4 GHz, so it loses nothing.
  bandsteering_mode = "off"

  # Never adopt or forget a device from Terraform.
  allow_adoption    = false
  forget_on_destroy = false
}

# ---- switch-01 ports -------------------------------------------------------
# One resource per port, so a mistake on one port doesn't rewrite the others.
# Ports 1 (OPNsense) and 4 (pve-01, which runs the controller) keep Management
# untagged with either profile, so moving them doesn't cut off the gateway or
# the controller.

import {
  for_each = { for k, v in local.switch_01_ports : k => v if contains(["7", "8"], k) }
  to       = unifi_device_port.switch_01[each.key]
  id       = "${local.switch_01_mac}/${each.key}"
}

resource "unifi_device_port" "switch_01" {
  for_each        = local.switch_01_ports
  device_mac      = local.switch_01_mac
  index           = tonumber(each.key)
  name            = each.value.name
  port_profile_id = local.port_profile_id[each.value.profile]

  # What the controller stores for these ports today; set so the plan doesn't
  # clear them.
  poe_mode           = "auto"
  setting_preference = "auto"
}
