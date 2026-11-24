# pve-01

Guests on pve-01 (MS-03). State prefix `stacks/pve-01`.

```bash
cp terraform.tfvars.example terraform.tfvars   # set the UniFi OS Server link
terraform init -backend-config=../../backend.hcl
terraform plan
```

## Prerequisites

- The Debian 13 cloud-init template (VMID 9000 by default) built with
  `bin/barn-pve-cloud-template` on pve-01.
- The `local` datastore allows the `snippets` content type (the template script
  already uses it). Snippets upload over SSH as `root` through your SSH agent.
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
