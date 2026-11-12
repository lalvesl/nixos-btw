# Intel Core i5-3210M / i5-3230M laptop (Ivy Bridge, Intel HD 4000 graphics)
# running from a spinning HDD. Nothing here is specific to the desktop.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ata_piix / ahci cover the SATA controller of any 2nd/3rd generation Core
  # mobile chipset (HM65, HM67, HM75, HM77); the rest cover USB and card readers.
  boot.initrd.availableKernelModules = [
    "ahci"
    "ata_piix"
    # AES-NI: the passphrase is checked and the disk decrypted in hardware.
    "aesni_intel"
    "cryptd"
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Layout made by install-laptop-i5 (see installer.nix) on /dev/sda:
  #   1  1 MiB   BIOS boot (GRUB core image on a GPT disk, legacy BIOS)
  #   2  1 GiB   ESP, FAT32, mounted on /boot (kernels and initrds; not encrypted)
  #   3  rest    LUKS2 "cryptroot" holding a bcachefs
  # The root is found by partition label, so only GRUB below names the disk.
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-partlabel/cryptroot";

  # bcachefs is an out-of-tree module on this kernel. It sits on top of LUKS2
  # rather than using its own encryption, so the passphrase prompt is the usual
  # one and the key slots are managed with cryptsetup.
  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "bcachefs";
    # noatime: no write on every read, which matters on a spinning disk.
    options = [ "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # GPT disk that boots on both firmware types: GRUB is installed twice, as
  # BIOS code in the bios_grub partition and as the removable EFI binary. A
  # 2012 laptop is often legacy BIOS, but some are UEFI, so the image does not
  # have to know which one it is.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    # Old kernels pile up on a 1 GiB ESP.
    configurationLimit = 10;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.timeout = 3;

  # The Wi-Fi card is Atheros: ath9k needs no firmware file, and the
  # redistributable firmware covers the newer Atheros chips and the Bluetooth part
  # of combo cards.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;

  # HD 4000 is driven by the in-kernel i915; this adds hardware video decode.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];

  # Laptop: keep the 22 nm chip cool and let it clock down on battery.
  services.thermald.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  # HDD: bfq shares the disk fairly between a boot that reads thousands of small
  # files and everything else, so the desktop stays usable while it warms up.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';
  # Prefer dropping page cache over swapping to a slow disk; zram (zram.nix)
  # is the swap, so this only keeps the kernel from favouring it too eagerly.
  boot.kernel.sysctl."vm.swappiness" = 60;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
