# Colmena deployment hive
# Usage: colmena apply --on orangepi
{
  nixpkgs,
  inputs,
  pkgsCross,
  rk3588SpecialArgs,
  rk3588Path,
}:
{
  meta = {
    nixpkgs = pkgsCross;
    specialArgs = rk3588SpecialArgs // {
      inherit nixpkgs inputs;
    };
  };

  orangepi =
    { pkgs, ... }:
    {
      deployment = {
        targetHost = "192.168.1.100"; # update with board IP after first boot
        targetUser = "root";
        buildOnTarget = false;

        # The encrypted secrets file is gitignored, so it is not part of the
        # closure colmena copies. Upload it separately, before activation, so
        # sops-install-secrets finds it when the activation script runs.
        #
        # keyFile is a string rather than a Nix path on purpose: a path literal
        # would be copied into the store, which is exactly what keeping the file
        # out of git is meant to avoid. Colmena reads it locally at deploy time.
        #
        # destDir is persistent storage, not the default /run/keys: the board
        # must be able to decrypt on a reboot, not only right after a deploy.
        keys."orangepi.yaml" = {
          keyFile = "/home/lalvesl/super_balas/nixos-btw/secrets/cloud/orangepi.yaml";
          destDir = "/var/lib/sops";
          user = "root";
          group = "root";
          permissions = "0400";
          uploadAt = "pre-activation";
        };
      };

      nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";

      imports = [
        (import "${toString rk3588Path}/modules/boards/orangepi5.nix")
        ./orangepi/configuration.nix
        ./orangepi/cross-fixes.nix
        # Root filesystem and boot entries for the installed system; sdcard.nix
        # only covers the image.
        ./orangepi/deployed.nix
        # Passwords and service secrets, decrypted on the board itself at
        # activation. Kept out of the SD image on purpose -- see orangepi/bootstrap.nix.
        ./orangepi/secrets.nix
      ];
    };
}
