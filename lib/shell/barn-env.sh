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
