{ pkgs, ... }:

{
  # users.users.lalvesl = {
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

  # Multi architecture.
  #
  # aarch64-linux is load-bearing for the orangepi deployment, not a
  # convenience: it is what lets `colmena apply` build the board's system here
  # natively instead of cross-compiling it. A cross-built derivation hashes
  # differently from the aarch64 build Hydra published, so it matches nothing in
  # cache.nixos.org. Measured on that configuration, cross meant 1938
  # derivations to build and 14.6 GiB to fetch, against 518 and 3.9 GiB
  # natively. Removing aarch64-linux here would quietly bring that back.
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
  users.users.lalvesl.extraGroups = [
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
      storageDriver = "btrfs";
    };
  };
  users.groups.libvirtd.members = [
    "root"
    "lalvesl"
  ];

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

    qemu
    quickemu
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
    adwaita-icon-theme
  ];
}
