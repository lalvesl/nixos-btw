{
  pkgs,
  modulesPath,
  lib,
  ...
}:

let
  hashedPassword =
    let
      val = builtins.getEnv "WALLET_HASHED_PASSWORD";
    in
    if val == "" then
      builtins.throw "WALLET_HASHED_PASSWORD env var not set. Run build.sh instead of nix build directly."
    else
      val;
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Identity
  networking.hostName = "lalvesl-wallet";

  # Air-gapped: disable all networking by default
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;
  networking.useDHCP = lib.mkForce false;
  hardware.bluetooth.enable = false;

  # Enable niri
  programs.niri.enable = true;

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Graphics + camera
  hardware.graphics.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    # Terminal + browser
    kitty
    alacritty
    firefox

    # System tools
    git
    wget
    curl
    parted

    # Niri/Wayland tools
    waybar
    swaybg
    swaylock-effects
    rofi
    wl-clipboard
    cliphist
    mako

    # Bitcoin wallets
    electrum
    sparrow

    # QR code tools
    zbar
    qrencode

    # Camera
    v4l-utils
    guvcview

    # Security / key management
    gnupg
    keepassxc

    # Misc
    brightnessctl
  ];

  # User
  users.mutableUsers = false;

  users.users.root = {
    inherit hashedPassword;
  };

  users.users.lalvesl-wallet = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];
    inherit hashedPassword;
  };

  # Auto-login to niri
  services.getty.autologinUser = lib.mkForce "lalvesl-wallet";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  nixpkgs.config.allowUnfree = true;
}
