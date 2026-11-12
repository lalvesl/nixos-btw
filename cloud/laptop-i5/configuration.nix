# Second computer: Intel i5-3210M / i5-3230M laptop with an HDD.
# Same desktop as the main machine (niri, waybar, shell, terminal, networking),
# without what that hardware cannot run or does not need: NVIDIA, Steam,
# gamebox, MATLAB, the KVM sandbox, Docker/libvirt, Flatpak, sops secrets, and
# the heavy editor/IDE set. See README.md for building and flashing.
{
  lib,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./password.nix

    # Shared with the main machine.
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/cups.nix
    ../../nixos/modules/env.nix
    ../../nixos/modules/fonts.nix
    ../../nixos/modules/hotstarter.nix
    ../../nixos/modules/i18n.nix
    ../../nixos/modules/kde_connect.nix
    ../../nixos/modules/keyring.nix
    ../../nixos/modules/lan-mouse.nix
    ../../nixos/modules/net.nix
    ../../nixos/modules/niri.nix
    ../../nixos/modules/portals.nix
    ../../nixos/modules/ports.nix
    ../../nixos/modules/qt.nix
    ../../nixos/modules/sound.nix
    ../../nixos/modules/special-configs.nix
    ../../nixos/modules/ssh.nix
    ../../nixos/modules/user.nix
    ../../nixos/modules/wifi-hotspot.nix
    ../../nixos/modules/xserver.nix
    ../../nixos/modules/zram.nix
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
  nixpkgs.config.allowUnfree = true;

  # xserver.nix is written for the NVIDIA desktop; this laptop has no NVIDIA
  # card and no tearing option to set.
  services.xserver.deviceSection = lib.mkForce "";

  # No sops key exists on this machine, so the password comes from the build
  # environment instead (password.nix).
  users.users.${vars.username}.packages = [ pkgs.nautilus ];

  # The lighter half of nixos/packages.nix and dev-dependencies.nix.
  environment.systemPackages = with pkgs; [
    # Desktop apps
    firefox-bin
    alacritty
    kitty
    zathura
    mpv
    pavucontrol
    playerctl
    blueman
    resources
    kalker
    mako
    libnotify

    # Compositor, bar and Wayland tools used by the niri/waybar config
    waybar
    swaylock-effects
    swaybg
    awww
    wlsunset
    brightnessctl
    xwayland
    xwayland-satellite
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    imv
    papirus-nord
    home-manager

    # CLI and dev
    git
    neovim
    helix
    vim
    nixd
    nixfmt
    fzf
    tmux
    jq
    ripgrep
    fd
    sd
    htop
    lazygit
    ranger
    fastfetch
    file
    tree
    wget
    unzip
    zip
    gnumake
    gcc
    inotify-tools
    openssl
    ntfs3g
    bluez
    bluez-tools
  ];

  system.stateVersion = "25.05";
}
