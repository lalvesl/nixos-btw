# Nextcloud with PostgreSQL, Redis, full-text search, OCR and video thumbnails.
#
# This is the heaviest thing on the board by a wide margin, and Elasticsearch is
# most of that weight: it is a JVM service that wants gigabytes of heap and does
# not degrade gracefully when it does not get them. The heap is pinned low here
# and the unit is capped, which makes indexing slow rather than fatal. If the
# board starts thrashing, this is the first service to turn off -- full-text
# search is the feature you lose, and Nextcloud keeps working without it.
#
# Elasticsearch is also unfree (SSPL since 7.11). The allowUnfree predicate for
# it lives in flake.nix, on the pkgs instance itself: colmena hands the hive an
# externally created instance, and NixOS refuses `nixpkgs.config` alongside one.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "cloud.h.lalvesl.com";
in
{
  services.nextcloud = {
    enable = true;
    # Fresh install, so start on the current major. Nextcloud refuses upgrades
    # that skip a major version, which is why the pin is explicit.
    package = pkgs.nextcloud33;
    hostName = domain;
    https = false; # TLS terminates at the proxy / tunnel

    database.createLocally = true;
    configureRedis = true;

    maxUploadSize = "4G";

    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets."nextcloud/admin-password".path;
    };

    settings = {
      trusted_domains = [
        domain
        "192.168.1.100"
      ];
      # The gateway connects from loopback, so that is the only proxy to trust.
      trusted_proxies = [ "127.0.0.1" ];
      overwriteprotocol = "https";
      default_phone_region = "BR";

      # Thumbnails for video need ffmpeg on PATH; see extraEnv below.
      enabledPreviewProviders = [
        "OC\\Preview\\Image"
        "OC\\Preview\\HEIC"
        "OC\\Preview\\TIFF"
        "OC\\Preview\\Movie"
        "OC\\Preview\\MP4"
        "OC\\Preview\\MKV"
        "OC\\Preview\\AVI"
      ];
    };

    phpOptions = {
      # PHP's own ceiling, kept under the unit's MemoryMax below. The module
      # defaults this to 4G, which on this board is a promise it cannot keep.
      "memory_limit" = lib.mkForce "768M";
      "opcache.memory_consumption" = "128";
      "opcache.interned_strings_buffer" = "16";
    };

    # Eight cores, but PHP-FPM is not entitled to all of them.
    poolSettings = {
      pm = "dynamic";
      "pm.max_children" = "16";
      "pm.start_servers" = "3";
      "pm.min_spare_servers" = "2";
      "pm.max_spare_servers" = "5";
    };
  };

  # ffmpeg for video thumbnails, tesseract for OCR of scanned documents. Both
  # are looked up on PATH by the Nextcloud apps that use them, so they have to
  # be in the service environment rather than merely installed.
  systemd.services.phpfpm-nextcloud.path = with pkgs; [
    ffmpeg
    tesseract
    imagemagick
  ];

  systemd.services.phpfpm-nextcloud.serviceConfig = {
    MemoryMax = "3G";
    CPUWeight = 150; # interactive: outranks Jellyfin and the CI runner
  };

  # The vhost nginx builds for Nextcloud is bound to loopback in proxy.nix; the
  # gateway is the only thing that reaches it.

  # PostgreSQL tuned for a board, not a server: a small shared_buffers, and a
  # work_mem low enough that sixteen PHP workers cannot multiply it into swap.
  services.postgresql.settings = {
    shared_buffers = "512MB";
    effective_cache_size = "2GB";
    work_mem = "8MB";
    maintenance_work_mem = "128MB";
    max_connections = 50;
    random_page_cost = 1.1; # flash, not spinning rust
  };

  systemd.services.postgresql.serviceConfig.MemoryMax = "2G";

  # Full-text search backend.
  services.elasticsearch = {
    enable = true;
    listenAddress = "127.0.0.1";
    extraJavaOptions = [
      "-Xms1g"
      "-Xmx1g"
    ];
  };

  systemd.services.elasticsearch.serviceConfig = {
    MemoryMax = "2G";
    CPUWeight = 20; # indexing is batch work; it yields to everything
    IOWeight = 20;
  };
}
