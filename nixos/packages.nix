{ pkgs, ... }:
{
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
    # cudnnSupport = true;
    # permittedInsecurePackages = ["python-2.7.18.8" "electron-25.9.0"];
  };

  users.users."lalvesl" = {
    packages = with pkgs; [
      nautilus
    ];
  };

  environment.systemPackages = with pkgs; [
    # Desktop apps
    # audacity
    linuxKernel.packages.linux_zen.cpupower
    chromium
    google-chrome
    brave
    firefox
    zathura
    # telegram-desktop
    alacritty
    kitty
    obs-studio
    rofi
    wofi
    mpv
    discord
    # kdenlive
    # gparted
    # obsidian
    # zoom-us
    # pcmanfm-qt

    neofetch
    file
    tree
    wget
    git
    fastfetch
    htop
    nix-index
    unzip
    scrot
    ffmpeg
    light
    lux
    mediainfo
    ranger
    zram-generator
    cava
    zip
    ntfs3g
    yt-dlp
    brightnessctl
    swww
    openssl
    lazygit
    bluez
    bluez-tools

    fortune

    # GUI utils
    feh
    imv
    dmenu
    screenkey
    mako
    gromit-mpx

    # Xorg stuff
    #xterm
    #xclip
    #xorg.xbacklight

    # Wayland stuff
    xwayland
    wl-clipboard
    cliphist

    # WMs and stuff
    herbstluftwm
    hyprland
    seatd
    xdg-desktop-portal-hyprland
    polybar
    waybar
    hyprlock
    hyprshade

    # GPU stuff
    #nvidia-somethink-someday
    cudatoolkit
    ncurses5

    # Screenshotting
    grim
    grimblast
    slurp
    flameshot
    swappy

    # Other
    home-manager
    spice-vdagent
    # libsForQt5.qtstyleplugin-kvantum
    # libsForQt5.qt5ct
    papirus-nord
  ];

  fonts.packages = with pkgs; [
    jetbrains-mono
    noto-fonts
    noto-fonts-emoji
    twemoji-color-font
    font-awesome
    powerline-fonts
    powerline-symbols
    nerd-fonts.symbols-only
    nerd-fonts._0xproto
    # (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
  ];
}
