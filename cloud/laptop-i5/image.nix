# Raw disk image for the i5 laptop: a GPT disk with a BIOS boot partition, an
# EFI system partition and an ext4 root, so one image boots on legacy BIOS and
# on UEFI. Write it straight to the HDD (see README.md).
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  system.build.diskImage = import (modulesPath + "/../lib/make-disk-image.nix") {
    inherit config lib pkgs;
    name = "lalvesl-i5";
    format = "raw";
    partitionTableType = "hybrid";
    label = "nixos";
    bootSize = "512M";
    # The root only has to hold the system; first boot grows it to the whole
    # disk (boot.growPartition + autoResize in hardware.nix).
    diskSize = "auto";
    additionalSpace = "1G";
    installBootLoader = true;
    touchEFIVars = false;
    memSize = 2048;
  };
}
