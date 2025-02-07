{pkgs, ...}:

{
  # Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  users.users.alves = {
      extraGroups = [ "podman" ];
      subGidRanges = [
          {
              count = 65536;
              startGid = 1000;
          }
      ];
      subUidRanges = [
          {
              count = 65536;
              startUid = 1000;
          }
      ];
  };
  # Multi architecture
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "x86_64-windows"
  ];

  # Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  # Virtmanager
  virtualisation.libvirtd.enable = true;
  programs.virt-manager = {
    enable = true;
    package = pkgs.virt-manager;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    distrobox
    podman
    podman-compose

    docker-compose
  ];
}
