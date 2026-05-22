{ ... }:
{
  imports = [
    ./zsh.nix
    ./git.nix
    ./alacritty.nix
    ./kitty.nix
    ./htop.nix
    ./gtk.nix
    ./rofi.nix
    ./helix.nix
    ./wms/mod.nix
  ];

  home.username = "lalvesl";
  home.homeDirectory = "/home/lalvesl";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
