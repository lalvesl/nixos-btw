# Colmena deployment hive
# Usage: colmena apply --on orangepi
#
# Built natively for aarch64, not cross-compiled, and the difference is not
# stylistic. A cross-built derivation hashes differently from the aarch64 one
# Hydra published, so it matches nothing in cache.nixos.org and everything gets
# rebuilt from source. Measured on this configuration:
#
#   cross-compiled   1938 derivations to build, 14.6 GiB to fetch
#   native aarch64    518 derivations to build,  3.9 GiB to fetch
#
# The 1420 that disappear are the ones nobody wants to build by hand: the whole
# Python interpreter plus 299 packages behind Home Assistant, the .NET runtime
# behind Jellyfin, Qt, Node. Natively those all substitute.
#
# The x86_64 build host runs aarch64 builds through binfmt emulation -- see
# nixos/modules/binfmt.nix on the desktop. Emulation is slow per instruction,
# but it only has to cover what is genuinely not in the cache, which after this
# change is mostly generated config files plus the Pingora gateway.
#
# The SD image (nixosConfigurations.orangepi) stays cross-compiled: it builds
# fine that way today, and the bootstrap path is not worth disturbing.
{
  nixpkgs,
  inputs,
  pkgsNative,
  rk3588Path,
}:
{
  meta = {
    nixpkgs = pkgsNative;
    specialArgs = {
      rk3588 = {
        inherit nixpkgs;
        # The board modules build kernel packages with this. Native here too,
        # for the same cache reason as everything else.
        pkgsKernel = pkgsNative;
      };
      # dtb-install.nix lists this arg but never uses it
      nixos-generators = { };
      inherit nixpkgs inputs;
    };
  };

  orangepi =
    { ... }:
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

      nixpkgs.hostPlatform = "aarch64-linux";

      imports = [
        (import "${toString rk3588Path}/modules/boards/orangepi5.nix")
        ./orangepi/configuration.nix
        # Note: cross-fixes.nix is deliberately absent. It disables systemd's
        # BPF framework to work around a cross-compilation failure, and that
        # costs RestrictFileSystems=, RestrictNetworkInterfaces=, SocketBind*=
        # and IPAddress{Allow,Deny}= enforcement -- all of which the service
        # stack relies on. Building natively removes the reason for it.
        # The SD image still imports it, because that build is still cross.
        #
        # Root filesystem and boot entries for the installed system; sdcard.nix
        # only covers the image.
        ./orangepi/deployed.nix
        # Passwords and service secrets, decrypted on the board itself at
        # activation. Kept out of the SD image on purpose -- see orangepi/bootstrap.nix.
        ./orangepi/secrets.nix
        # The home-lab service stack.
        ./orangepi/services/mod.nix
      ];
    };
}
