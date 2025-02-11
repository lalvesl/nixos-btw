{pkgs, ...}:

{
  # users.users.alves = {
  #     extraGroups = [ "podman" ];
  #     subGidRanges = [
  #         {
  #             count = 65536;
  #             startGid = 1000;
  #         }
  #     ];
  #     subUidRanges = [
  #         {
  #             count = 65536;
  #             startUid = 1000;
  #         }
  #     ];
  # };

  # Multi architecture
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "x86_64-windows"
  ];

  programs.virt-manager = {
    enable = true;
    package = pkgs.virt-manager;
  };

  virtualisation = {
    libvirtd.enable = true;
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    oci-containers.backend = "podman";

    docker = {
      enable = true;
      storageDriver = "btrfs";
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    distrobox

    podman
    podman-compose

    dive
    docker-compose
  ];
}
