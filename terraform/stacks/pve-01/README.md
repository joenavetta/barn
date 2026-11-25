# pve-01

Guests on pve-01 (MS-03). State prefix `stacks/pve-01`.

```bash
cp terraform.tfvars.example terraform.tfvars   # set the UniFi OS Server link
terraform init -backend-config=../../backend.hcl
terraform plan
```

## TODO: real certificate

pve-01 uses `insecure = true` in `providers.tf` for now because it still
serves its self-signed cert. Next step: ACME via Terraform with the bpg
resources `proxmox_virtual_environment_acme_account`, `_acme_dns_plugin` and
`_acme_certificate`. Use Cloudflare DNS-01 with a DNS-edit token scoped to
cowshed.cc, stored in 1Password (e.g. `proxmox.acme.cloudflare`). One ACME
account covers both nodes, and Proxmox renews the cert on its own. Then remove
`insecure`. pve-02 needs the same.

Open decisions: the Let's Encrypt contact email, and which Cloudflare token
(globals expects `terraform.cloudflare.default`; the vault has
`terraform.cloudflare.dns`).

## Prerequisites

- The Debian 13 cloud-init template (VMID 9000 by default) built with
  `bin/barn-pve-cloud-template` on pve-01. A reinstalled node has no template,
  so rebuild it: copy `bin/barn-pve-cloud-template` to the node and run
  `barn-pve-cloud-template 9000 debian-13 https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2`.
- The `local` datastore allows the `snippets` content type. The template script
  enables it; otherwise run
  `pvesm set local --content iso,vztmpl,backup,import,snippets`. Snippets upload
  over SSH as `root` through your SSH agent.
- `module.globals.ssh_public_keys` holds your admin key, or the VM has no SSH
  login.

## unifi: UniFi OS Server

VM at 10.42.1.5 in Management, `unifi.home.cowshed.cc`. Cloud-init installs
Podman and runs the UniFi OS Server installer on first boot, which takes a few
minutes after Terraform finishes. Progress is in
`/var/log/cloud-init-output.log`; rerun `/usr/local/sbin/install-unifi-os-server`
if it failed.

After it is up:

1. Open `https://10.42.1.5:11443/`, finish setup, and save the local admin as
   `unifi.webui.admin` in 1Password.
2. Adopt the switch and APs. On the Management network they find it by L2
   discovery; otherwise SSH to the device and run
   `set-inform http://10.42.1.5:8080/inform`.
3. Create the `terraform.unifi.default` API key for the `unifi` stack.

Ports devices need to reach: 8080/tcp (inform), 3478/udp (STUN),
10001/udp (discovery). Web UI: 11443/tcp.

UniFi OS updates itself from its UI. Changing `unifi_os_server_url` later only
matters for a rebuilt VM.
