#!/usr/bin/env bash
# Write a password hash into a sops file without the cleartext passing through
# shell history, the command line, or the screen.
#
#   ./secrets/set-password.sh secrets/cloud/orangepi.yaml users/lalvesl/hashed-password
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <sops-file> <secret/path>" >&2
  echo "e.g.:  $0 secrets/cloud/orangepi.yaml users/root/hashed-password" >&2
  exit 1
fi

file="$1"
path="$2"

for bin in sops mkpasswd; do
  command -v "$bin" >/dev/null || { echo "$bin not found -- run inside 'nix develop'" >&2; exit 1; }
done

read -rsp "Password for ${path}: " p1; echo >&2
read -rsp "Confirm: " p2; echo >&2
[ "$p1" = "$p2" ] || { echo "passwords do not match" >&2; exit 1; }
[ -n "$p1" ] || { echo "empty password" >&2; exit 1; }

hash=$(printf '%s' "$p1" | mkpasswd -m sha-512 -s)
unset p1 p2

# sops set wants the path as indices: ["users"]["lalvesl"]["hashed-password"]
index=""
IFS='/' read -ra parts <<< "$path"
for part in "${parts[@]}"; do
  index+="[\"${part}\"]"
done

# The value goes in as JSON. The sha-512 crypt alphabet contains no quotes or
# backslashes, so wrapping it in quotes is enough.
sops set "$file" "$index" "\"$hash\""
echo "wrote ${path} to ${file}"
