# Terraform

- `stacks/<name>/` are root modules, one per system, each with its own state.
  Reusable modules are in `modules/`. The list of planned stacks is in
  [stacks/stacks.md](stacks/stacks.md).
- Every stack loads `modules/globals` for shared settings and reads secrets
  from the 1Password `Home Infrastructure` vault via the `onepassword` provider.
  The provider takes its credentials from the environment: the read-only
  service account token, or the desktop app (Touch ID) without one. Source
  `lib/shell/op-env.sh` from `~/.zshrc` to set them; see
  [docs/1password-service-account.md](../docs/1password-service-account.md).
  Nothing secret goes in `.tf` files or tfvars.
- Proxmox uses [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest).

## Adding a stack

1. `mkdir stacks/<name>` with `backend.tf` (unique `prefix`), `providers.tf`
   (load `globals`, fetch the credential, configure the provider), `main.tf`.
2. Add its 1Password item title to `modules/globals` (naming: [docs/secrets.md](../docs/secrets.md)).
3. `terraform init -backend-config=../../backend.hcl`.

## State

State can contain secrets (provider tokens, generated passwords), so it is
remote, private, and versioned. Each stack sets its own `prefix`; the bucket is
shared through a partial backend file:

```bash
cp backend.hcl.example backend.hcl   # in terraform/; set the bucket name
```

The legacy (pre-upgrade) state lives in the same GCS bucket under the old
`terraform` prefix. Leave it alone until those VMs are retired.

## Proxmox API user

Run `barn-op proxmox-token <node>`. It creates the
`terraform@pve` user and `TerraformProv` role on the node over SSH, issues a
token, and stores it in 1Password as `terraform.proxmox.<node>`, which is
the item this stack reads. The token never touches your terminal.
