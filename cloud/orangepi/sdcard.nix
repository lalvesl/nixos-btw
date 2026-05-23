{ nixpkgs, lib, config, pkgs, ... }:
let
  rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
  uboot = pkgs.ubootOrangePi5;
in {
  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image.nix"
  ];

  boot = {
    kernelParams = [
      "root=UUID=${rootPartitionUUID}"
      "rootfstype=ext4"
    ];
    consoleLogLevel = 7;

    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };
  };

  sdImage = {
    inherit rootPartitionUUID;
    compressImage = true;
    populateFirmwareCommands = "";
    firmwareSize = 1;
    firmwarePartitionName = "UNUSED";
    firmwarePartitionOffset = 32;

    populateRootCommands = ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';

    postBuildCommands = ''
      dd if=${uboot}/idbloader.img of=$img seek=64 conv=fsync,notrunc
      dd if=${uboot}/u-boot.itb of=$img seek=16384 conv=fsync,notrunc
    '';
  };
}
