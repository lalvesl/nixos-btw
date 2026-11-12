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
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Same labels the disk image builder gives its partitions, so the image boots
  # no matter whether the disk shows up as sda, sdb or something else.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true; # first boot grows it to fill the whole HDD
    # noatime: no write on every read, which matters on a spinning disk.
    options = [ "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  boot.growPartition = true;

  # GPT disk that boots on both firmware types: GRUB is installed twice, as
  # BIOS code in the bios_grub partition and as the removable EFI binary. A
  # 2012 laptop is often legacy BIOS, but some are UEFI, so the image does not
  # have to know which one it is.
  boot.loader.grub = {
    enable = true;
    # The disk as the image builder's VM sees it. The BIOS stage is bound to the
    # partition table, not to this name, so the HDD can be /dev/sda here.
    device = "/dev/vda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.timeout = 3;

  # Redistributable firmware covers most Intel Wi-Fi. Broadcom Wi-Fi cards
  # (common in this generation) also need `hardware.enableAllFirmware = true`
  # plus allowUnfree; left off until the card is known.
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
