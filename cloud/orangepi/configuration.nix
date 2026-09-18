{ pkgs, lib, ... }:
{
  imports = [ ./valheim.nix ];

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

  # Runs the x86_64 dedicated server under box64. The password comes from sops
  # in cloud/orangepi/secrets.nix; in the SD image, which has no sops, the
  # service generates a random one in /var/lib/valheim/password on first start.
  services.valheim = {
    enable = true;
    serverName = "orangepi";
    worldName = "Dedicated";
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

    # Public key: perfectly fine in cleartext in the repo. It is what lets
    # secrets.nix turn off SSH password authentication.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYtFQr+WJHP6PAXxrLRvpdSg6aYQrFEAZdq6jI/YsAd alvesdelima.lucas45@gmail.com"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYtFQr+WJHP6PAXxrLRvpdSg6aYQrFEAZdq6jI/YsAd alvesdelima.lucas45@gmail.com"
  ];

  system.stateVersion = "26.05";
}
