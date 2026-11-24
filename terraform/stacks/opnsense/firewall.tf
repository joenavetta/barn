# Inter-VLAN and internet rules. OPNsense routes between VLANs, so these are
# the only rules that matter; the UniFi switch just carries tagged traffic.
#
# Rules are per ingress interface, first match wins, and every interface ends
# in a logged block, so anything not listed here is denied. The matrix is in
# the plan doc ("Network design > Firewall matrix").
#
# Each rule: iface, desc, src, dst (alias, CIDR, "(self)" or "any"),
# optional proto (default any), port (alias or number), invert (negate dst).

locals {
  a = { for k, v in opnsense_firewall_alias.net : k => v.name }
  h = { for k, v in opnsense_firewall_alias.host : k => v.name }
  p = { for k, v in opnsense_firewall_alias.port : k => v.name }

  internet = { dst = opnsense_firewall_alias.private.name, invert = true }

  # Until dns-01/dns-02 exist, clients use the gateway's resolver (Unbound on
  # OPNsense). Flip this when AdGuard is up.
  dns_on_gateway = true
  dns_dst        = local.dns_on_gateway ? "(self)" : local.h.dns

  rules = [
    # Management: infra devices and Proxmox hosts
    { iface = "mgmt", desc = "Mgmt to DNS", src = local.a.mgmt, dst = local.dns_dst, proto = "TCP/UDP", port = local.p.dns },
    { iface = "mgmt", desc = "Mgmt to SMTP relay", src = local.a.mgmt, dst = local.h.smtp, proto = "TCP", port = local.p.smtp },
    { iface = "mgmt", desc = "Mgmt to Servers (PBS, NFS, guests)", src = local.a.mgmt, dst = local.a.servers },
    merge({ iface = "mgmt", desc = "Mgmt to internet (updates)", src = local.a.mgmt }, local.internet),

    # Trusted: family laptops and phones at home
    { iface = "trusted", desc = "Trusted to DNS", src = local.a.trusted, dst = local.dns_dst, proto = "TCP/UDP", port = local.p.dns },
    { iface = "trusted", desc = "Trusted to reverse proxy", src = local.a.trusted, dst = local.h.caddy, proto = "TCP", port = local.p.web },
    { iface = "trusted", desc = "Trusted to IoT (HomeKit, casting)", src = local.a.trusted, dst = local.a.iot },
    { iface = "trusted", desc = "Admin devices to Management", src = opnsense_firewall_alias.admin_devices.name, dst = local.a.mgmt },
    { iface = "trusted", desc = "Admin devices to Servers", src = opnsense_firewall_alias.admin_devices.name, dst = local.a.servers },
    { iface = "trusted", desc = "Admin devices to Cameras", src = opnsense_firewall_alias.admin_devices.name, dst = local.a.cameras },
    merge({ iface = "trusted", desc = "Trusted to internet", src = local.a.trusted }, local.internet),

    # Servers: Proxmox guests and the Synology
    { iface = "servers", desc = "Synology pulls camera streams", src = local.h.synology, dst = local.a.cameras },
    { iface = "servers", desc = "Monitoring/NetBox to Management", src = local.h.monitors, dst = local.a.mgmt },
    { iface = "servers", desc = "Monitoring to Home Assistant", src = local.h.monitors, dst = local.h.homeassistant },
    merge({ iface = "servers", desc = "Servers to internet", src = local.a.servers }, local.internet),

    # Proxy: Caddy only; reaches the app backends and nothing else inside
    { iface = "proxy", desc = "Proxy to DNS", src = local.a.proxy, dst = local.dns_dst, proto = "TCP/UDP", port = local.p.dns },
    { iface = "proxy", desc = "Caddy to app backends", src = local.h.caddy, dst = local.h.app_backends, proto = "TCP", port = local.p.app_backends },
    { iface = "proxy", desc = "Proxy to SMTP relay", src = local.a.proxy, dst = local.h.smtp, proto = "TCP", port = local.p.smtp },
    merge({ iface = "proxy", desc = "Proxy to internet (ACME, Tailscale, CrowdSec)", src = local.a.proxy }, local.internet),

    # IoT
    { iface = "iot", desc = "IoT to DNS", src = local.a.iot, dst = local.dns_dst, proto = "TCP/UDP", port = local.p.dns },
    merge({ iface = "iot", desc = "IoT to internet", src = local.a.iot }, local.internet),

    # Cameras: no internet; NTP from the gateway only
    { iface = "cameras", desc = "Cameras NTP from gateway", src = local.a.cameras, dst = "(self)", proto = "UDP", port = "123" },

    # Guest: internet and the gateway's resolver only
    { iface = "guest", desc = "Guest DNS on gateway", src = local.a.guest, dst = "(self)", proto = "TCP/UDP", port = local.p.dns },
    merge({ iface = "guest", desc = "Guest to internet", src = local.a.guest }, local.internet),

    # Exit node: internet only, never the home networks or the tailnet range
    { iface = "exitnode", desc = "Exit DNS on gateway", src = local.a.exitnode, dst = "(self)", proto = "TCP/UDP", port = local.p.dns },
    merge({ iface = "exitnode", desc = "Exit node to internet", src = local.a.exitnode }, local.internet),

    # Tailscale subnet router (traffic from the tailnet into the home subnets).
    # The tailnet policy already limits this to group:admins; this is the
    # second layer.
    { iface = "tailscale", desc = "Tailnet to Management", src = "100.64.0.0/10", dst = local.a.mgmt },
    { iface = "tailscale", desc = "Tailnet to Servers", src = "100.64.0.0/10", dst = local.a.servers },
    { iface = "tailscale", desc = "Tailnet to IoT", src = "100.64.0.0/10", dst = local.a.iot },
  ]

  # Same attributes on every rule, so they fit one map type.
  normalized = [for r in local.rules : {
    iface  = r.iface
    desc   = r.desc
    src    = r.src
    dst    = r.dst
    proto  = try(r.proto, "any")
    port   = try(r.port, "")
    invert = try(r.invert, false)
  }]

  # Only interfaces that have been assigned (var.interfaces) get rules.
  active_rules = {
    for i, r in local.normalized :
    format("%02d-%s", i, replace(lower(r.desc), "/[^a-z0-9]+/", "-")) => merge(r, { seq = 100 + i * 10 })
    if contains(keys(var.interfaces), r.iface)
  }

  # Ingress interfaces that get a final logged block.
  blocked_ifaces = toset([for k in distinct([for r in local.rules : r.iface]) : k if contains(keys(var.interfaces), k)])
}

resource "opnsense_firewall_filter" "pass" {
  for_each    = local.active_rules
  enabled     = true
  sequence    = each.value.seq
  description = each.value.desc

  interface = {
    interface = [var.interfaces[each.value.iface]]
  }

  filter = {
    quick       = true
    action      = "pass"
    direction   = "in"
    ip_protocol = "inet"
    protocol    = each.value.proto
    source = {
      net = each.value.src
    }
    destination = {
      net    = each.value.dst
      port   = each.value.port
      invert = each.value.invert
    }
    log = false
  }
}

resource "opnsense_firewall_filter" "block" {
  for_each    = local.blocked_ifaces
  enabled     = true
  sequence    = 9000
  description = "Block and log everything else (${each.key})"

  interface = {
    interface = [var.interfaces[each.key]]
  }

  filter = {
    quick     = true
    action    = "block"
    direction = "in"
    protocol  = "any"
    source = {
      net = "any"
    }
    destination = {
      net = "any"
    }
    log = true
  }
}
