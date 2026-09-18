# Jellyfin and qBittorrent.
#
# Jellyfin is the one service here that can actually use the board's hardware
# well: the RK3588 has a video engine, and the vendor kernel is the reason this
# system is pinned to it. Software transcoding eight cores' worth of H.264 will
# saturate the box and starve everything else, so transcoding is capped and the
# unit is deprioritised against the interactive services.
{ config, lib, ... }:
{
  services.jellyfin = {
    enable = true;
    openFirewall = false; # reached through nginx only
  };

  systemd.services.jellyfin.serviceConfig = {
    MemoryMax = "3G";
    CPUWeight = 50; # below the default 100: yields to Nextcloud and Home Assistant
    IOWeight = 50;
  };

  services.qbittorrent = {
    enable = true;
    # openFirewall would open the WebUI port as well, and the WebUI is only
    # reachable through the gateway now. The torrent port is opened by hand in
    # firewall.nix instead.
    openFirewall = false;
    webuiPort = 8080;
    torrentingPort = 51413;

    serverConfig = {
      Preferences = {
        # The WebUI is only ever reached through the reverse proxy on loopback.
        WebUI = {
          Address = "127.0.0.1";
          LocalHostAuth = false;
          CSRFProtection = true;
        };
      };
      BitTorrent.Session = {
        # Flash storage and a modest CPU: keep the cache small and the queue short.
        AsyncIOThreadsCount = 4;
        DiskCacheSize = 64;
        MaxActiveDownloads = 3;
        MaxActiveTorrents = 8;
        MaxActiveUploads = 3;
      };
    };
  };

  systemd.services.qbittorrent.serviceConfig = {
    MemoryMax = "1G";
    CPUWeight = 30;
    IOWeight = 30;
  };

  # Hardware video acceleration for Jellyfin on the RK3588.
  users.users.jellyfin.extraGroups = lib.mkAfter [
    "video"
    "render"
  ];
}
