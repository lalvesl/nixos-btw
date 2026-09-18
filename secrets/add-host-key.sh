#!/usr/bin/env bash
# Convert a machine's SSH host key into the matching age key and print what
# needs to go into .sops.yaml. This is what breaks the first-boot chicken-and-egg:
# a host's age identity only exists once it has generated its host key.
#
#   ./secrets/add-host-key.sh orangepi 192.168.1.100
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <alias> <host-or-ip>" >&2
  exit 1
fi

alias_name="$1"
target="$2"

command -v ssh-to-age >/dev/null || { echo "ssh-to-age not found -- run inside 'nix develop'" >&2; exit 1; }

echo "fetching the ed25519 host key of ${target}..." >&2
agekey=$(ssh-keyscan -t ed25519 "$target" 2>/dev/null | grep -v '^#' | ssh-to-age)

[ -n "$agekey" ] || { echo "could not get a host key from ${target}" >&2; exit 1; }

cat >&2 <<EOF

age key for ${alias_name}:

    ${agekey}

Three steps left:

  1. In .sops.yaml, under 'keys:', uncomment and fill the ${alias_name} line:
         - &${alias_name} ${agekey}

  2. Still in .sops.yaml, uncomment '- *${alias_name}' in the creation_rule for
     the matching file.

  3. Re-encrypt so the new key actually takes effect -- changing .sops.yaml on
     its own does nothing to what is already encrypted:
         sops updatekeys secrets/cloud/${alias_name}.yaml

EOF
