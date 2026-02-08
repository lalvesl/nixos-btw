{ pkgs, ... }:
{
  programs.kdeconnect = {
    enable = true;
    # package = pkgs.kdeconnect-kde;
    # package = pkgs.gnomeExtensions.gsconnect;
  };
  environment.etc."kdeconnect/config".text = ''
    [General]
    preferredReceivePath=/home/lalvesl/Downloads/kde_connect
  '';
}
