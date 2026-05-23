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

# Hash user password for NixOS (sha-512 with random salt)
export WALLET_HASHED_PASSWORD
WALLET_HASHED_PASSWORD=$(printf '%s' "$user_pass" | mkpasswd -m sha-512 -s)

# Store LUKS password hash locally (never embedded in ISO)
printf '%s' "$luks_pass" | mkpasswd -m sha-512 -s > "$SCRIPT_DIR/.luks-hash"
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
