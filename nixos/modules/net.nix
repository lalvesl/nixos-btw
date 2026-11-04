{ config, pkgs, ... }:
{

  networking.networkmanager.enable = true;
  networking.hostName = "lalvesl-nix"; # Define your hostname.
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
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

  # Tailscale client. tailscale0 is deliberately not a trusted interface here:
  # this is a desktop, and tailnet peers should not reach its local services.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;
    extraSetFlags = [
      # Lets the waybar switch run `tailscale up/down` without root.
      "--operator=lalvesl"
      # 192.168.100.0/24 is advertised by the home server, so its address works
      # the same away from home.
      "--accept-routes"
      # Split DNS from the admin console: h.lalvesl.com is answered by the home
      # server's blocky.
      "--accept-dns"
    ];
  };

  # Split DNS needs a resolver that can send one domain to one server.
  # NetworkManager hands its DNS to systemd-resolved, and tailscaled adds the
  # tailnet domains there instead of overwriting /etc/resolv.conf.
  services.resolved.enable = true;

  # The home server's blocky answers h.lalvesl.com, and only that domain is sent
  # to it. The LAN address comes first: it works at home with the VPN off, and
  # away from home through the subnet route. The tailnet address is the fallback.
  services.resolved.dnsDelegates.homelab.Delegate = {
    DNS = "192.168.100.100 100.94.106.0";
    Domains = "~h.lalvesl.com";
  };

  # Always on after a boot. `tailscale down` is remembered across reboots, so a
  # switch left off would otherwise stay off. A machine that has never logged in
  # (NeedsLogin) is left alone, as that needs a person.
  systemd.services.tailscale-autoconnect = {
    description = "Bring Tailscale up at boot";
    after = [
      "tailscaled.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      config.services.tailscale.package
      pkgs.jq
      pkgs.coreutils
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      state=
      for _ in $(seq 30); do
        state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty')
        case "$state" in Running | Stopped | NeedsLogin) break ;; esac
        sleep 1
      done
      if [ "$state" = Stopped ]; then
        tailscale up
      fi
    '';
  };

  # services.network-manager-applet.enable = true;
}
