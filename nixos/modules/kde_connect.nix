{ pkgs, ... }:
{
  programs.kdeconnect = {
    enable = true;
    package = pkgs.plasma5Packages.kdeconnect-kde;
  };
  environment.etc."kdeconnect/config".text = ''
    [General]
    preferredReceivePath=/home/lalvesl/Downloads/kde_connect
  '';
}
