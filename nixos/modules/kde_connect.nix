{ pkgs, vars, ... }:
{
  programs.kdeconnect = {
    enable = true;
    # package = pkgs.kdeconnect-kde;
    # package = pkgs.gnomeExtensions.gsconnect;
  };
  environment.etc."kdeconnect/config".text = ''
    [General]
    preferredReceivePath=${vars.home}/Downloads/kde_connect
  '';
}
