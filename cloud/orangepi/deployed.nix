# The board as an already-installed system, which is what colmena deploys to.
#
# The SD image gets its root filesystem and boot entries from sd-image.nix, by
# way of sdcard.nix. That module is image-only: it describes how to lay bytes
# down on a card, not how a running board boots. Without the equivalent for the
# installed system a colmena evaluation fails on the two stock assertions --
# "the 'fileSystems' option does not specify your root file system" and the
# grub.devices one.
#
# Imported by cloud/colmena.nix only.
{ lib, ... }:
let
  # Written into the card by sdcard.nix; keep the two in sync.
  rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
in
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/${rootPartitionUUID}";
    fsType = "ext4";
  };

  boot = {
    kernelParams = [
      "root=UUID=${rootPartitionUUID}"
      "rootfstype=ext4"
    ];

    # The RK3588 boots through U-Boot and extlinux, never grub.
    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };
  };
}
