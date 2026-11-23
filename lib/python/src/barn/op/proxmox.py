"""barn-op proxmox-token: Terraform API token on a Proxmox node."""

from __future__ import annotations

import json
import shlex
import subprocess
import sys

from onepassword import ItemCategory

from barn.op import config, naming, vault
from barn.op.naming import ItemName

PVE_USER = "terraform@pve"
PVE_TOKEN_ID = "tf"
PVE_ROLE = "TerraformProv"
# Privileges for the bpg/proxmox provider; check its docs when upgrading PVE.
PVE_PRIVS = " ".join([
    "Datastore.AllocateSpace", "Datastore.AllocateTemplate", "Datastore.Audit",
    "Pool.Allocate", "Sys.Audit", "Sys.Console", "Sys.Modify",
    "VM.Allocate", "VM.Audit", "VM.Clone", "VM.Config.CDROM", "VM.Config.Cloudinit",
    "VM.Config.CPU", "VM.Config.Disk", "VM.Config.HWType", "VM.Config.Memory",
    "VM.Config.Network", "VM.Config.Options", "VM.Migrate", "VM.PowerMgmt", "SDN.Use",
])

# Runs on the node. Everything except the token JSON goes to stderr.
REMOTE = r"""
set -euo pipefail
user=$1 token=$2 role=$3 privs=$4
if pveum role list --output-format json | grep -q "\"roleid\":\"$role\""; then
  pveum role modify "$role" -privs "$privs" >&2
else
  pveum role add "$role" -privs "$privs" >&2
fi
pveum user list --output-format json | grep -q "\"userid\":\"$user\"" ||
  pveum user add "$user" --comment "Terraform (barn)" >&2
pveum acl modify / -user "$user" -role "$role" >&2
pveum user token add "$user" "$token" --privsep 0 --comment "Terraform (barn)" --output-format json
"""


async def create_terraform_token(node: str) -> None:
    naming.validate_segment("node", node)
    host = f"{node}.{config.HOME_DOMAIN}"
    name = ItemName("terraform", "proxmox", node)

    # Check 1Password first so we don't mint a token we can't store.
    client = await vault.connect()
    vid = await vault.vault_id(client)
    if await vault.item_exists(client, vid, name.title):
        raise SystemExit(
            f"error: '{name.title}' already exists in {config.VAULT}; to rotate, delete "
            f"the token on {node} and archive the item first"
        )

    print(f"Configuring {PVE_USER} on {host}...", file=sys.stderr)
    # ssh joins its arguments into one remote command line, so quote each one.
    remote_cmd = "bash -s -- " + " ".join(
        shlex.quote(a) for a in (PVE_USER, PVE_TOKEN_ID, PVE_ROLE, PVE_PRIVS)
    )
    result = subprocess.run(
        ["ssh", f"root@{host}", remote_cmd],
        input=REMOTE, stdout=subprocess.PIPE, text=True, check=False,
    )
    if result.returncode != 0:
        raise SystemExit(f"error: configuring {host} failed (ssh exit {result.returncode})")
    token = json.loads(result.stdout)
    secret = f"{token['full-tokenid']}={token['value']}"

    item = vault.NewItem(
        title=name.title,
        category=ItemCategory.APICREDENTIALS,
        tags=naming.tags("terraform", "proxmox", "proxmox"),
        notes=(
            f"Proxmox API token for Terraform on {node} (https://{host}:8006/), "
            f"role {PVE_ROLE} on / (privsep off). "
            "Credential is the full user!id=secret string."
        ),
        username=f"{PVE_USER}!{PVE_TOKEN_ID}",
        secret=secret,
    )
    await vault.create(client, vid, item)
    print(f"Created '{name.title}' in {config.VAULT}", file=sys.stderr)
    print(f"Reference: {item.reference}", file=sys.stderr)
