#!/usr/bin/env bash
# Shared by the bin/ launchers. Source it; don't run it.

# barn_load_env <file>: export each KEY=value in a dotenv file, unless KEY is
# already set in the environment (so the shell always wins). Handles blank
# lines, # comments, an optional "export " prefix, and "..." or '...' quoting.
# Values are taken literally: no $VAR expansion or command substitution.
barn_load_env() {
  local file=$1 line key value
  [[ -f $file ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line#"${line%%[![:space:]]*}"}          # trim leading space
    [[ -z $line || $line == \#* ]] && continue
    line=${line#export }
    [[ $line == *=* ]] || continue
    key=${line%%=*}
    value=${line#*=}
    [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "warning: $file: bad line: $line" >&2; continue; }
    if [[ $value =~ ^\"(.*)\"$ || $value =~ ^\'(.*)\'$ ]]; then
      value=${BASH_REMATCH[1]}
    fi
    [[ -n ${!key+set} ]] && continue
    export "$key=$value"
  done < "$file"
}

# barn_op_auth: choose how the commands reach 1Password, from BARN_OP_AUTH:
#   auto (default)   use a service account token if there is one, else the
#                    desktop app (Touch ID)
#   service-account  require a token; fail instead of falling back
#   desktop          ignore any token and use the desktop app
# The token is OP_SERVICE_ACCOUNT_TOKEN from the environment, or else the
# macOS Keychain generic password whose service is $BARN_OP_KEYCHAIN_SERVICE
# (see docs/1password-service-account.md). It is exported only to the command
# the launcher runs, never to your shell.
barn_op_auth() {
  local mode=${BARN_OP_AUTH:-auto} token
  case $mode in
    desktop)
      unset OP_SERVICE_ACCOUNT_TOKEN
      return 0 ;;
    auto | service-account) ;;
    *)
      echo "error: BARN_OP_AUTH must be auto, service-account or desktop (got '$mode')" >&2
      return 1 ;;
  esac
  if [[ -z ${OP_SERVICE_ACCOUNT_TOKEN:-} && -n ${BARN_OP_KEYCHAIN_SERVICE:-} ]] \
    && command -v security >/dev/null; then
    token=$(security find-generic-password -s "$BARN_OP_KEYCHAIN_SERVICE" -w 2>/dev/null) || token=
    [[ -n $token ]] && export OP_SERVICE_ACCOUNT_TOKEN=$token
  fi
  if [[ $mode == service-account && -z ${OP_SERVICE_ACCOUNT_TOKEN:-} ]]; then
    echo "error: BARN_OP_AUTH=service-account, but OP_SERVICE_ACCOUNT_TOKEN is not set and the" \
      "Keychain has no '${BARN_OP_KEYCHAIN_SERVICE:-}' item (docs/1password-service-account.md)" >&2
    return 1
  fi
  return 0
}
