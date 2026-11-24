# Second computer: Intel i5-3210M / i5-3230M laptop with an HDD.
# The same desktop and the same software as the main machine -- niri, waybar,
# shell, browsers, editors, Claude Code, Antigravity, MATLAB, the KVM sandbox,
# containers -- through the same shared modules, minus what only the main machine
# has or does: the NVIDIA GPU (and CUDA), Steam and the game container, its GRUB
# replacement for systemd-boot, and its sops secrets. See README.md.
{
  lib,
  vars,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./password.nix
    ./ssh.nix

    # Shared with the main machine (nixos/modules/mod.nix), in the same order.
    ../../nixos/packages.nix
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/dev-dependencies.nix
    ../../nixos/modules/env.nix
    ../../nixos/modules/flatpak.nix
    ../../nixos/modules/fonts.nix
    ../../nixos/modules/niri.nix
    ../../nixos/modules/i18n.nix
    ../../nixos/modules/kde_connect.nix
    ../../nixos/modules/keyring.nix
    ../../nixos/modules/lan-mouse.nix
    ../../nixos/modules/matlab.nix
    ../../nixos/modules/net.nix
    ../../nixos/modules/nix-priority.nix
    ../../nixos/modules/wifi-hotspot.nix
    ../../nixos/modules/ports.nix
    ../../nixos/modules/qt.nix
    ../../nixos/modules/sound.nix
    ../../nixos/modules/special-configs.nix
    ../../nixos/modules/sys-utils.nix
    ../../nixos/modules/portals.nix
    ../../nixos/modules/hotstarter.nix
    ../../nixos/modules/user.nix
    ../../nixos/modules/virtualization-containerization.nix
    ../../nixos/modules/xserver.nix
    ../../nixos/modules/zram.nix
    ../../nixos/modules/sandbox
  ];

  networking.hostName = lib.mkForce "lalvesl-i5";

  # The LUKS passphrase is typed in the initrd, before any keyboard setting of
  # the desktop applies, so the layout has to be loaded that early.
  console.keyMap = "br-abnt2";
  console.earlySetup = true;
  time.timeZone = "America/Sao_Paulo";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # xserver.nix is written for the NVIDIA desktop; this laptop has no NVIDIA
  # card and no tearing option to set.
  services.xserver.deviceSection = lib.mkForce "";

  # The shared module picks Docker's btrfs storage driver, which needs a btrfs
  # root. This laptop's root is a bcachefs, so use the generic overlay driver.
  # Not tested on bcachefs: if Docker refuses to start, `vfs` works anywhere,
  # at the cost of space and speed.
  virtualisation.docker.storageDriver = lib.mkForce "overlay2";

  # No sops key exists on this machine, so the password comes from the build
  # environment instead (password.nix).

  system.stateVersion = "25.05";
}
