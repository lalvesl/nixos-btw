# Secrets for the desktop (lalvesl-nix).
#
# The values live encrypted in secrets/desktop.yaml, which is gitignored and
# therefore never leaves this machine. At activation sops-nix decrypts them into
# /run/secrets/<name>, which is ramfs -- unlike tmpfs it can never be paged out
# to disk, and it is wiped on shutdown, so the decryption happens again on every
# boot.
#
# The one rule that must not be broken: never read a secret with
# builtins.readFile, and never interpolate one into a Nix string. Either copies
# the cleartext into the store, which is world-readable. Always use the options
# that take a path -- hashedPasswordFile, EnvironmentFile, LoadCredential,
# passwordFile.
{ inputs, ... }:
let
  # Absolute path, deliberately a string and not a Nix path: the encrypted files
  # are gitignored, and a flake can only read files git tracks. As a string it
  # never enters the flake source or the store -- sops-install-secrets opens it
  # straight off the live filesystem at activation.
  #
  # The cost of that is a hardcoded location: move the repository and this must
  # move with it.
  secretsDir = "/home/lalvesl/super_balas/nixos-btw/secrets";
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = "${secretsDir}/desktop.yaml";
    defaultSopsFormat = "yaml";

    # Existence and shape of the file can no longer be checked at build time,
    # because it is not in the store. A missing or malformed file now fails the
    # switch instead of the build.
    validateSopsFiles = false;

    age = {
      # This machine runs no sshd, so there is no SSH host key to derive an age
      # identity from. It gets an age key of its own instead.
      keyFile = "/var/lib/sops-nix/key.txt";

      # Safety net: if the file goes missing (reinstall, lost /var) sops-nix
      # generates a new key rather than failing activation. The new key decrypts
      # nothing -- its public half has to be added to .sops.yaml and the files
      # re-encrypted with `sops updatekeys`.
      generateKey = true;
    };

    # No GPG in this repository; the default would pick up the sshd RSA host
    # keys, which do not exist here either.
    gnupg.sshKeyPaths = [ ];

    secrets = {
      # Smoke test: proves the whole chain works (host key -> decrypt ->
      # /run/secrets) without any service depending on it. Check it with
      # `sudo cat /run/secrets/example` after the switch, then drop it once
      # there are real secrets here.
      example.mode = "0400";

      # Real secrets go below. The shape:
      #
      #   "wifi/home-psk" = { };                  # -> /run/secrets/wifi/home-psk
      #   "tokens/github" = {
      #     owner = "lalvesl";                    # who may read it
      #     mode = "0400";
      #     restartUnits = [ "some.service" ];    # restarted on rotation
      #   };
    };
  };
}
