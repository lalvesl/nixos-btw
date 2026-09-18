#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt_password() {
  local label="$1"
  local pass1 pass2
  while true; do
    read -rsp "$label: " pass1; echo >&2
    read -rsp "Confirm:  " pass2; echo >&2
    if [[ "$pass1" == "$pass2" ]]; then
      printf '%s' "$pass1"
      return
    fi
    echo "Passwords do not match. Try again." >&2
  done
}

echo "=== LUKS Encryption Password ==="
luks_pass=$(prompt_password "LUKS password")

echo "=== User & Root Password (lalvesl-wallet / root) ==="
user_pass=$(prompt_password "User/root password")

# Hash the user password for NixOS.
#
# yescrypt, not sha512crypt, and not argon2. argon2 is the one you would reach
# for, and it cannot be used: PAM validates /etc/shadow through libxcrypt,
# which has never implemented it, so the ISO would build and then refuse every
# login. yescrypt is the memory-hard scheme libxcrypt does implement -- an
# attacker has to spend memory per guess, which is what rules out cracking on
# GPUs. sha512crypt is only CPU-expensive and does not.
export WALLET_HASHED_PASSWORD
WALLET_HASHED_PASSWORD=$(printf '%s' "$user_pass" | mkpasswd -m yescrypt -s)

# Store a verifier for the LUKS passphrase locally (never embedded in the ISO).
#
# Read the warning before relying on this. LUKS does not use crypt(3) hashes,
# so this file is not a key and unlocks nothing -- its only use is checking
# later that you remember the passphrase you chose. What it *is*, on disk, is
# an offline-crackable verifier for the passphrase guarding a wallet volume.
# Anyone who copies this file can grind at it without touching the disk it
# protects, and without you noticing.
#
# yescrypt at least makes that grinding memory-hard rather than merely
# CPU-bound. The safer move is to not keep the file at all.
printf '%s' "$luks_pass" | mkpasswd -m yescrypt -s > "$SCRIPT_DIR/.luks-hash"
chmod 600 "$SCRIPT_DIR/.luks-hash"

echo ""
echo "Building ISO..."
cd "$SCRIPT_DIR"
nix build .#nixosConfigurations.wallet-iso.config.system.build.isoImage \
  --impure \
  --out-link result \
  --show-trace

iso=$(find result/iso -name "*.iso" | head -1)
realpath "$iso" > "$SCRIPT_DIR/../latest_wallet_build"
echo ""
echo "ISO: $iso"
echo "LUKS hash stored at: $SCRIPT_DIR/.luks-hash (local only, not in ISO)"
