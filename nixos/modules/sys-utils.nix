{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gnome-software
    gnome-system-monitor
    gnome-disk-utility
  ];

}
