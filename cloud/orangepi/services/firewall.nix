# Firewall.
#
# Default-deny inbound. The list is short because almost nothing is reachable
# directly: every HTTP service listens on loopback and is reached through the
# Pingora gateway, which is the only thing bound to a routable address.
#
# Note what is deliberately absent: 8096 (Jellyfin), 8123 (Home Assistant), 8222
# (Vaultwarden), 8080 (qBittorrent WebUI), 5000 (Harmonia), 1883 (MQTT), 9200
# (Elasticsearch), 5432 (PostgreSQL). Opening any of them would let a machine on
# the LAN bypass the gateway and reach a service that expects the gateway to
# have decided whether it was allowed to.
{ ... }:
{
  networking.firewall = {
    enable = true;

    allowedTCPPorts = [
      443 # Pingora gateway, TLS -- the actual entry point
      80 # redirect to 443 only; serves nothing
      53 # blocky DNS
      51413 # qBittorrent peer traffic
      2456 # Valheim
      2457
    ];

    allowedUDPPorts = [
      53 # blocky DNS
      51413 # qBittorrent peer traffic
      2456 # Valheim
      2457
    ];

    # Traffic over the mesh is already authenticated by WireGuard. The gateway
    # still checks the source address before granting trusted access, so this
    # opens the interface, not the services behind it.
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose"; # required for Tailscale's routing to work
  };
}
