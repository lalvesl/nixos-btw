{ pkgs, ... }:
{
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.hyprland.withUWSM = true;

  environment.systemPackages = with pkgs; [
    hyprpaper
  ];
}
