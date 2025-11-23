{ pkgs, ... }:
{
  networking.networkmanager.enable = true;
  networking.hostName = "lalvesl-nix"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # KdeConnect ports
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];

  environment.systemPackages = with pkgs; [
    openconnect
    networkmanager-openconnect
    networkmanagerapplet
  ];

  networking.networkmanager.plugins = with pkgs; [ networkmanager-openconnect ];
  networking.firewall.trustedInterfaces = [ "tun0" ];

  networking.firewall.interfaces.tun0.allowedTCPPorts = [
    80
    443
    8080
  ];
  networking.firewall.interfaces.tun0.allowedUDPPorts = [ 53 ];

  # services.network-manager-applet.enable = true;
}
