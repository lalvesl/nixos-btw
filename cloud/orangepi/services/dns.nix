# Local DNS and ad blocking.
#
# Blocky rather than AdGuard Home: its entire configuration is declarative Nix,
# so the blocklists and the local zone live in this repository instead of in a
# web UI's mutable state, and it idles in a few tens of megabytes. AdGuard is
# the better pick if a household wants to click things; this board is not going
# to be administered that way.
#
# One naming scheme everywhere: *.h.lalvesl.com, resolved here to the board and
# resolved to Cloudflare from outside. That avoids a separate local zone, and in
# particular avoids .local, which is reserved for mDNS by RFC 6762 -- clients
# send those queries to multicast rather than to a resolver, so a .local zone
# served over unicast DNS works on some devices and silently fails on others.
{ lib, ... }:
let
  hostIP = "192.168.1.100"; # keep in sync with deployment.targetHost
in
{
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;

      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
        "https://dns.quad9.net/dns-query"
      ];

      # A mapping on the parent answers for every subdomain under it, so adding
      # a service needs no DNS change at all -- only a route in proxy.nix.
      customDNS.mapping."h.lalvesl.com" = hostIP;

      blocking = {
        denylists.ads = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };

  systemd.services.blocky.serviceConfig.MemoryMax = lib.mkDefault "256M";
}
