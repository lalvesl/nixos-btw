# The home server's binary cache (Harmonia), filled by its Forgejo pipeline with
# the systems of this repo. cache.nixos.org stays as it is, and anything missing
# here is simply built or fetched as before. Off until homelab.network.cache is
# set (see homelab-network.nix).
{ config, lib, ... }:
let
  cache = config.homelab.network.cache;
in
{
  nix.settings = lib.mkIf (cache.url != null && cache.publicKey != null) {
    extra-substituters = [ cache.url ];
    extra-trusted-public-keys = [ cache.publicKey ];
  };
}
