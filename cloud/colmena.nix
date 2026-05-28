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
      };

      nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";

      imports = [
        (import "${toString rk3588Path}/modules/boards/orangepi5.nix")
        ./orangepi/configuration.nix
      ];
    };
}
