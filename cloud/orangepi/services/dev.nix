# CI runner, binary cache, compilation cache and password manager.
#
# The runner and the cache are the reason this board is interesting as a build
# host at all: it is an aarch64 machine with a real /nix/store, so it can build
# and then serve aarch64 closures that an x86_64 laptop would otherwise have to
# cross-compile or emulate.
#
# It is also the part of the stack that will happily consume the entire machine.
# Everything here is batch work, so it all runs at a CPU weight well below the
# interactive services and with hard memory ceilings.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Dynamically linked binaries that expect a normal FHS -- which is most
  # prebuilt CI tooling, and the Steam server binaries.
  programs.nix-ld.enable = true;

  services.github-runners.orangepi = {
    enable = true;
    url = "https://github.com/lalvesl/nixos-btw";
    tokenFile = config.sops.secrets."github-runner/token".path;

    # Bare metal with the host's Nix daemon, not a container: the point is to
    # reuse the local /nix/store, so a build that already happened is not
    # repeated.
    extraLabels = [
      "nixos"
      "aarch64"
      "self-hosted"
    ];

    extraPackages = with pkgs; [
      git
      nix
      cachix
    ];

    # Without this the runner gets a private /nix and every job starts cold.
    serviceOverrides = {
      MemoryMax = "4G";
      CPUWeight = 20;
      IOWeight = 20;
      # The runner has to reach the daemon socket to use the shared store.
      BindPaths = [ "/nix/var/nix/daemon-socket" ];
    };
  };

  # Harmonia serves the local store as a binary cache, signed so other machines
  # can trust it. The private half is generated once and kept in sops; the
  # public half goes in the consuming machines' nix.settings.trusted-public-keys.
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.sops.secrets."harmonia/signing-key".path ];
    settings = {
      bind = "127.0.0.1:5000";
      workers = 2;
    };
  };

  systemd.services.harmonia.serviceConfig = {
    MemoryMax = "512M";
    CPUWeight = 40;
  };

  # sccache has no NixOS module -- verified absent from the pinned nixpkgs -- so
  # it is wired up as a plain service plus the environment that makes rustc and
  # the C compilers actually use it. The cache is shared, which is the point:
  # the CI runner and an interactive build hit the same entries.
  environment.systemPackages = [ pkgs.sccache ];

  systemd.services.sccache = {
    description = "sccache shared compilation cache server";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.sccache} --start-server";
      Environment = [
        "SCCACHE_DIR=/var/cache/sccache"
        "SCCACHE_CACHE_SIZE=20G"
        "SCCACHE_IDLE_TIMEOUT=0"
      ];
      CacheDirectory = "sccache";
      Restart = "on-failure";
      MemoryMax = "1G";
      CPUWeight = 20;
    };
  };

  environment.variables = {
    RUSTC_WRAPPER = "${lib.getExe pkgs.sccache}";
    SCCACHE_DIR = "/var/cache/sccache";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = config.sops.secrets."vaultwarden/env".path;
    config = {
      DOMAIN = "https://vault.h.lalvesl.com";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      WEBSOCKET_ENABLED = true;
    };
  };

  systemd.services.vaultwarden.serviceConfig.MemoryMax = lib.mkDefault "256M";
}
