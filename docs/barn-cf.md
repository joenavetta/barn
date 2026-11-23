# barn-cf: rotating Cloudflare API tokens

`barn-cf rotate <item>` rolls a Cloudflare **account-owned** API token with the
roll API (`PUT /accounts/{account_id}/tokens/{token_id}/value`). The token keeps
its ID, name and permissions; only the secret changes, and **the old secret stops
working immediately**. The new value is saved back to the 1Password item, then
pushed to whatever uses it.

```sh
barn-cf link caddy.acme.cloudflare --account-id <account id>   # once per item
barn-cf show terraform.cloudflare.dns                          # name, status, last rotated
barn-cf rotate terraform.cloudflare.dns --dry-run              # check, change nothing
barn-cf rotate terraform.cloudflare.dns                        # asks before rolling
```

## Token items

Each rotatable token is an ApiCredentials item named `<service>.<subsystem>.<name>`
(create it with `barn-op new-item ApiCredentials ... --target cloudflare`), with:

| Field | What |
|---|---|
| `credential` | the token secret |
| `account id` | Cloudflare account ID |
| `token id` | the token's ID (not secret); `barn-cf link` finds it by verifying the token |
| `last rotated` | set by `barn-cf rotate` (UTC) |

| Item | Used by | Push after rotate |
|---|---|---|
| `terraform.cloudflare.dns` | Terraform (reads 1Password at plan time) | none |
| `caddy.acme.cloudflare` | Caddy DNS-01 on the proxy | hook in [`hooks.py`](../lib/python/src/barn/cf/hooks.py), **a stub until the proxy is built**: barn-cf refuses to roll it unless you pass `--skip-push` and update Caddy by hand |

To add a push for another consumer, write a function in `hooks.py` and register
it in `HOOKS` under the item title.

## The admin token

Rolling needs a separate token, kept only in 1Password as
`barn.cloudflare.token-admin` (`BARN_CF_ADMIN_ITEM` in [`config/barn.env`](../config/barn.env)):

- Create it in the dashboard under **Manage Account > Account API Tokens**
  (an account-owned token), with the single permission
  **Account > API Tokens > Edit**. The API calls this
  `Account API Tokens Write`, the only permission the roll endpoint accepts.
- Store it with
  `pbpaste | barn-op new-item ApiCredentials barn cloudflare token-admin --target cloudflare --description "Rolls Cloudflare account API tokens (barn-cf)"`.
- It is read through the 1Password app (Touch ID) each run and never written to disk.
- It can create and edit any token in the account, so don't copy it anywhere
  else. Consider an IP restriction to your home WAN and an expiry; barn-cf
  doesn't rotate the admin token itself (roll it in the dashboard).

Exit codes: 0 done, 1 error (nothing rolled unless the output says "Rolled"),
2 bad item name, 3 rolled and saved but the consumer still needs the new value.
