{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "psmouse.synaptics_intertouch=0" ];

  # The newest kernel (7.3), for the btrfs performance work that landed in 7.2
  # and 7.3. The NVIDIA legacy_580 module is built against it
  # (config.boot.kernelPackages in nvidia.nix) and compiles. To go back to the
  # default kernel, remove this line, or pick the previous generation in the
  # boot menu.
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
