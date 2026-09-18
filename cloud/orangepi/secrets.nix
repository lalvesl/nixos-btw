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

      # Token that sits in the control panel URL. Read by the gateway at
      # startup, which refuses to run if it is shorter than 24 characters.
      "valheim/control-token" = {
        owner = "homelab-gateway";
        mode = "0400";
        restartUnits = [ "homelab-gateway.service" ];
      };

      # Home-lab stack. Each secret is owned by the one service that reads it;
      # restartUnits means rotating a value in sops takes effect on the next
      # activation instead of needing a manual restart.

      # Bare token. The path is fixed because proxy.nix renders it into an env
      # file through sops.templates rather than reading it directly.
      "cloudflared_tunnel_token" = {
        mode = "0400";
        restartUnits = [ "cloudflared-tunnel.service" ];
      };

      # Scoped Cloudflare API token (Zone:DNS:Edit on this zone only) used by
      # lego for the DNS-01 challenge. Distinct from the tunnel token above:
      # different capability, different blast radius if either leaks.
      "acme/cloudflare-dns-token" = {
        mode = "0400";
        restartUnits = [ "acme-h.lalvesl.com.service" ];
      };

      "nextcloud/admin-password" = {
        owner = "nextcloud";
        mode = "0400";
      };

      "mosquitto/homeassistant-password" = {
        owner = "mosquitto";
        mode = "0400";
        restartUnits = [ "mosquitto.service" ];
      };

      "github-runner/token" = {
        mode = "0400";
        restartUnits = [ "github-runner-orangepi.service" ];
      };

      # Private half of the binary cache signing key. The public half is not a
      # secret and belongs in the consuming machines' trusted-public-keys.
      # Root-only: harmonia runs under DynamicUser and takes the key through
      # LoadCredential, so there is no static user to own the file.
      "harmonia/signing-key" = {
        mode = "0400";
        restartUnits = [ "harmonia.service" ];
      };

      # ADMIN_TOKEN and friends, in EnvironmentFile syntax rather than a bare
      # value -- vaultwarden takes its configuration from the environment.
      "vaultwarden/env" = {
        owner = "vaultwarden";
        mode = "0400";
        restartUnits = [ "vaultwarden.service" ];
      };

      # Restic: the repository URL, the encryption password, and the S3
      # credentials as AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
      "restic/repository".mode = "0400";
      "restic/password".mode = "0400";
      "restic/s3-env".mode = "0400";
    };
  };

  users.mutableUsers = false;
  users.users.lalvesl.hashedPasswordFile = config.sops.secrets."users/lalvesl/hashed-password".path;
  users.users.root.hashedPasswordFile = config.sops.secrets."users/root/hashed-password".path;

  services.valheim.passwordFile = config.sops.secrets."valheim/password".path;

  # Off at boot. The unit is driven by the control panel in services/proxy.nix,
  # so leaving it in multi-user.target would mean every reboot silently starts
  # a server the panel then shows as running without anyone asking for it.
  systemd.services.valheim.wantedBy = lib.mkForce [ ];

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
