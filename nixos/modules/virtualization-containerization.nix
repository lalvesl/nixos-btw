{ pkgs, ... }:

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

  # Enable dconf (System Management Tool)
  programs.dconf.enable = true;

  # Add user to libvirtd group
  users.users.alves.extraGroups = [
    "libvirtd"
    "podman"
  ];

  services.spice-vdagentd.enable = true;

  # Manage the virtualisation services
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        ovmf.enable = true;
        ovmf.packages = [ pkgs.OVMFFull.fd ];
      };
    };
    spiceUSBRedirection.enable = true;
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    oci-containers.backend = "podman";

    docker = {
      enable = true;
      # storageDriver = "btrfs";
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    distrobox

    podman
    podman-compose
    docker-compose
    dive
    runc # Container runtime
    conmon # Container runtime monitor
    skopeo # Interact with container registry
    slirp4netns # User-mode networking for unprivileged namespaces
    fuse-overlayfs # CoW for images, much faster than default vfs

    qemu_full
    quickemu
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    win-virtio
    win-spice
    adwaita-icon-theme
  ];
}
