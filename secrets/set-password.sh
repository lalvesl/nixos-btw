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

# yescrypt, not sha512crypt.
#
# argon2 is what you would reach for first, and it is not an option: PAM
# validates /etc/shadow through libxcrypt, which has never implemented argon2.
# No amount of generating one elsewhere helps -- the login would simply fail.
#
# yescrypt is the memory-hard scheme libxcrypt does implement, and it is the
# default on Debian and Fedora now. Unlike sha512crypt, which is only
# CPU-expensive, it forces an attacker to spend memory per guess, which is what
# takes GPU and ASIC cracking off the table.
hash=$(printf '%s' "$p1" | mkpasswd -m yescrypt -s)
unset p1 p2

# sops set wants the path as indices: ["users"]["lalvesl"]["hashed-password"]
index=""
IFS='/' read -ra parts <<< "$path"
for part in "${parts[@]}"; do
  index+="[\"${part}\"]"
done

# The value goes in as JSON. The crypt alphabet contains no quotes or
# backslashes, so wrapping it in quotes is enough.
sops set "$file" "$index" "\"$hash\""
echo "wrote ${path} to ${file}"
