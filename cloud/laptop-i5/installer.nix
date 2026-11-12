# Installer ISO for the i5 laptop. It carries the finished laptop system and a
# command that partitions the HDD (LUKS2 + bcachefs) and installs it, offline.
# It boots on legacy BIOS and on UEFI (isohybrid), so it can be written to a USB
# stick with dd. See README.md.
{
  lib,
  pkgs,
  modulesPath,
  laptop,
  ...
}:
let
  system = laptop.config.system.build.toplevel;

  install = pkgs.writeShellApplication {
    name = "install-laptop-i5";
    runtimeInputs = with pkgs; [
      bcachefs-tools
      coreutils
      cryptsetup
      dosfstools
      gptfdisk
      nixos-install-tools
      parted
      util-linux
    ];
    runtimeEnv.SYSTEM = "${system}";
    text = builtins.readFile ./install.sh;
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  networking.hostName = "lalvesl-i5-installer";
  image.baseName = lib.mkForce "lalvesl-i5-installer";

  # The module that makes the new disk readable from the live system.
  boot.supportedFilesystems = [ "bcachefs" ];

  # The passphrase is typed here and again at every boot: same layout both times.
  console.keyMap = "br-abnt2";

  # The whole laptop system lives in the ISO, so nixos-install never downloads.
  isoImage.storeContents = [ system ];
  # zstd builds much faster than the default xz and reads faster from a stick.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  environment.systemPackages = [ install ];

  services.getty.helpLine = ''

    Run `sudo install-laptop-i5` to erase /dev/sda and install the laptop.
  '';
}
