# DHCP reservations and DNS names in Dnsmasq. Unbound forwards home.cowshed.cc
# to Dnsmasq (10.42.1.1:53053), so these names resolve for every client.
#
# Only the hosts listed here are managed for now. Entries made by hand in the
# GUI (switch-01, pve-01, pve-02, unifi) stay manual until they're imported.
# DHCP ranges are manual too: the provider can't manage them.

locals {
  dnsmasq_managed = ["homeassist", "sensorpush"]

  # Reserve only once the MAC is known (module.globals.macs).
  dnsmasq_hosts = {
    for h in local.dnsmasq_managed : h => {
      ip  = local.hosts[h]
      mac = module.globals.macs[h]
    } if module.globals.macs[h] != ""
  }
}

resource "opnsense_dnsmasq_host" "this" {
  for_each           = local.dnsmasq_hosts
  hostname           = each.key
  domain             = module.globals.internal_domain
  ip_addresses       = [each.value.ip]
  hardware_addresses = [each.value.mac]
  description        = "Managed by barn (stacks/opnsense)"
}
