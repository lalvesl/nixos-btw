# Where the home lab lives: its domain, DNS servers and binary cache.
#
# The values are options with empty defaults, so this repository carries no
# address of its own. They are set by a module that lives in the private homelab
# repository (network.nix there) and is imported by the flake. Without it
# everything that depends on them simply stays off: no split DNS, no extra cache.
{ lib, ... }:
{
  options.homelab.network = {
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "home.example.org";
      description = "The domain the home server answers for (split DNS sends only it there).";
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.0.2.10"
        "198.51.100.10"
      ];
      description = ''
        The home server's DNS, in the order to try: the LAN address first (it
        works at home and, through the subnet route, away from it), then the
        tailnet one.
      '';
    };

    cache = {
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://cache.home.example.org";
        description = "The binary cache (Harmonia) filled by the home server's pipeline.";
      };
      publicKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "home.example.org-1:...";
        description = "The public half of the key the cache signs with.";
      };
    };
  };
}
