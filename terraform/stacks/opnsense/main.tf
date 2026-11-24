# VLAN devices and firewall aliases on OPNsense, which routes between VLANs.
# Rules are in firewall.tf, DHCP reservations in dnsmasq.tf.

locals {
  net   = module.globals.networks
  hosts = module.globals.hosts
  apps  = module.globals.proxied_apps

  tagged = { for k, n in local.net : k => n if !n.native && contains(var.networks_enabled, k) }
}

resource "opnsense_interfaces_vlan" "this" {
  for_each    = local.tagged
  parent      = var.trunk_parent
  tag         = each.value.vlan
  device      = "vlan0.${each.value.vlan}"
  description = each.value.name
}

# ---- Aliases -------------------------------------------------------------

resource "opnsense_firewall_alias" "net" {
  for_each    = local.net
  name        = "net_${each.key}"
  type        = "network"
  content     = [each.value.cidr]
  description = "${each.value.name} VLAN"
}

# Everything that is not the internet: RFC1918, CGNAT/tailnet, link-local.
resource "opnsense_firewall_alias" "private" {
  name        = "net_private"
  type        = "network"
  content     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "169.254.0.0/16"]
  description = "Non-internet destinations"
}

resource "opnsense_firewall_alias" "host" {
  for_each = {
    dns           = [local.hosts["dns-01"], local.hosts["dns-02"]]
    smtp          = [local.hosts.smtp]
    caddy         = [local.hosts.caddy]
    synology      = [local.hosts.synology]
    app_backends  = distinct([for a in local.apps : local.hosts[a.backend]])
    monitors      = [local.hosts.uptimekuma, local.hosts.netbox]
    homeassistant = [local.hosts.homeassist]
  }
  name    = "h_${each.key}"
  type    = "host"
  content = each.value
}

resource "opnsense_firewall_alias" "admin_devices" {
  name        = "h_admin_devices"
  type        = "host"
  content     = var.admin_devices
  description = "Admin laptops/phones on Trusted"
}

resource "opnsense_firewall_alias" "port" {
  for_each = {
    dns          = ["53"]
    web          = ["80", "443"]
    smtp         = ["25"]
    app_backends = distinct([for a in local.apps : tostring(a.port)])
  }
  name    = "p_${each.key}"
  type    = "port"
  content = each.value
}
