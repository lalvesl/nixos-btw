{ pkgs, modulesPath, ... }:

{
  imports = [
    # Verify this path exists in the nixpkgs checkout or reference it correctly via modulesPath
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Networking
  networking.hostName = "nixos-wallet";
  networking.wireless.enable = true; # Enable wireless support for the live ISO

  # Enable Hyprland
  programs.hyprland.enable = true;

  # Hardware Configuration for generic ISO
  # The installation-cd module handles most of this, but we need sound/video
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Webcam support
  hardware.opengl = {
    enable = true;
    # extraPackages = with pkgs; [ v4l-utils ]; # Often needed for webcam utils
  };

  # Packages
  environment.systemPackages = with pkgs; [
    # System tools
    kitty # Terminal
    firefox # Browser
    git
    wget
    curl
    parted

    # Hyprland tools
    wofi
    waybar
    dunst

    # Crypto Wallets
    electrum # Bitcoin & Lightning
    sparrow # Bitcoin
    # mycrypto-app    # Ethereum (AppImage valid alternative, or web-based)
    # framesh         # Another option, but let's stick to standard repo if available
    # metamask is a browser extension, so firefox is key

    # Utilities for QR and Webcam
    zbar # Barcode reading
    qrencode # QR code generation
    guvcview # Simple webcam viewer
    gnupg # PGP
    keepassxc # Password manager

    # Ethereum tools
    # go-ethereum     # geth
  ];

  # User Configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "networkmanager"
    ];
    password = "nixos"; # Default password for the live user
  };

  # Auto-login to Hyprland
  services.getty.autologinUser = "nixos";

  # Necessary for someelectron apps to run under Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Allow unfree packages (often needed for drivers or specific crypto software)
  nixpkgs.config.allowUnfree = true;
}
