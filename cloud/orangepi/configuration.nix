{ pkgs, lib, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking = {
    hostName = "orangepi";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  systemd.network.enable = true;

  time.timeZone = "America/Sao_Paulo";

  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    btop
    lm_sensors
    usbutils
    pciutils
    parted
    btrfs-progs
    mtdutils
    i2c-tools
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault true;
      X11Forwarding = lib.mkDefault false;
    };
    openFirewall = true;
  };

  # USB HDDs — add after identifying disks with lsblk/blkid
  # fileSystems."/mnt/storage" = {
  #   device = "/dev/disk/by-uuid/YOUR-UUID";
  #   fsType = "btrfs";
  #   options = [ "compress=zstd" "noatime" ];
  # };

  users.users.lalvesl = {
    isNormalUser = true;
    home = "/home/lalvesl";
    extraGroups = [
      "wheel"
      "disk"
    ];
    initialPassword = "changeme";
  };

  system.stateVersion = "26.05";
}
