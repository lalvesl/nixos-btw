# Secrets for the orangepi.
#
# Imported by colmena only (cloud/colmena.nix), never by the SD image.
#
# The encrypted file is gitignored, so it does not travel with the repository
# and cannot be referenced as a flake path. Colmena uploads it to the board
# before activation (see deployment.keys in cloud/colmena.nix) and sops reads it
# from there. It lands in /var/lib rather than the default /run/keys on purpose:
# /run is wiped on shutdown, and the board has to be able to decrypt its own
# secrets on a plain reboot, without waiting for the next deploy.
#
# Decryption happens on the board, with its SSH host key converted to age.
# Neither the local build nor the /nix/store ever sees cleartext.
#
# This module is also where the board stops accepting SSH passwords, so do not
# deploy it before confirming the public key in configuration.nix works.
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    # Where colmena drops the file, not where it lives in the repo. A string, so
    # it is read off the board filesystem instead of being copied into the store.
    defaultSopsFile = "/var/lib/sops/orangepi.yaml";
    defaultSopsFormat = "yaml";

    # Not verifiable at build time: the file is not in the store, and on the
    # build host it is not at this path either.
    validateSopsFiles = false;

    # The board's identity is the ed25519 host key generated on first boot.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];

    secrets = {
      # neededForUsers decrypts early, into /run/secrets-for-users, before users
      # are created. Without it hashedPasswordFile is read too soon and the
      # account ends up with no valid password.
      "users/lalvesl/hashed-password".neededForUsers = true;
      "users/root/hashed-password".neededForUsers = true;

      # Stays root-only: valheim.nix hands it to the unit with LoadCredential,
      # so the service user never needs to read the file itself.
      "valheim/password" = {
        mode = "0400";
        restartUnits = [ "valheim.service" ];
      };
    };
  };

  users.mutableUsers = false;
  users.users.lalvesl.hashedPasswordFile = config.sops.secrets."users/lalvesl/hashed-password".path;
  users.users.root.hashedPasswordFile = config.sops.secrets."users/root/hashed-password".path;

  services.valheim.passwordFile = config.sops.secrets."valheim/password".path;

  # With the public keys in place, password auth is only extra attack surface on
  # a machine that faces the network.
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;

  # Encrypted disks: a sops keyfile only works for volumes mounted AFTER
  # activation, because /run/secrets does not exist during initrd. For the USB
  # HDDs:
  #
  #   sops.secrets."disks/storage-keyfile" = { mode = "0400"; };
  #   environment.etc."crypttab".text = ''
  #     storage /dev/disk/by-uuid/UUID ${config.sops.secrets."disks/storage-keyfile".path} nofail
  #   '';
  #
  # This cannot work for the root disk: that needs an interactive passphrase, a
  # keyfile baked into the initrd, or a TPM via systemd-cryptenroll.
}
