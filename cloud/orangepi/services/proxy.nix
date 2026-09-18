# The edge gateway, the Cloudflare tunnel and the Tailscale mesh.
#
# The proxy is homelab-gateway, a small Pingora program kept in this repository
# under ../pingora. It exists because the interesting property here is not
# routing but trust: two kinds of traffic arrive at the same backends and must
# not be treated alike.
#
#   trusted listener   Reached over the tailnet. Traffic got here through
#                      WireGuard, so the peer is someone who was invited.
#                      Every route is available. The proxy still checks the
#                      source address is in Tailscale's CGNAT range, so a
#                      machine on the LAN that can reach port 80 does not
#                      inherit that trust.
#
#   tunnel listener    Loopback-only, and cloudflared is the only thing pointed
#                      at it. A route is reachable here only if it is marked
#                      public below. None are yet, so everything arriving from
#                      the public internet gets a 404 -- which is the truthful
#                      answer, not a placeholder.
#
# Publishing a service later is one `public = true;` in the route list and a
# redeploy. Nothing has to change in the Cloudflare dashboard, because the
# tunnel carries a single wildcard hostname and the gateway does the dispatch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "h.lalvesl.com";

  gateway = pkgs.callPackage ../pingora { };

  # Nextcloud is the exception to "everything is a plain HTTP backend": it is
  # PHP, so it needs a real web server, and the NixOS module builds an nginx
  # vhost for it. That nginx stays on loopback and the gateway treats it as just
  # another upstream. Pingora cannot replace it -- it proxies, it does not speak
  # FastCGI.
  nextcloudPort = 8085;

  routes = [
    {
      host = "jellyfin.${domain}";
      upstream = "127.0.0.1:8096";
    }
    {
      host = "cloud.${domain}";
      upstream = "127.0.0.1:${toString nextcloudPort}";
    }
    {
      host = "vault.${domain}";
      upstream = "127.0.0.1:8222";
    }
    {
      host = "ha.${domain}";
      upstream = "127.0.0.1:8123";
    }
    {
      host = "torrent.${domain}";
      upstream = "127.0.0.1:8080";
    }
    {
      host = "cache.${domain}";
      upstream = "127.0.0.1:5000";
    }
  ];

  certDir = config.security.acme.certs."${domain}".directory;

  gatewayConfig = pkgs.writers.writeJSON "homelab-gateway.json" {
    trusted_listen = "0.0.0.0:443";
    cert_path = "${certDir}/fullchain.pem";
    key_path = "${certDir}/key.pem";
    redirect_listen = "0.0.0.0:80";
    tunnel_listen = "127.0.0.1:8081";

    control = {
      host = "valheim.${domain}";
      token_file = config.sops.secrets."valheim/control-token".path;
      unit = "valheim.service";
      # The unit goes active well before the game answers: starting it pulls in
      # valheim-update first, which downloads two gigabytes, and the Unity
      # server then loads the world before binding anything. Watching the port
      # is what makes "running" on the panel mean "you can connect".
      ready_port = config.services.valheim.port;
    };
    # `public` defaults to false on the Rust side, so an unpublished route needs
    # no marker here.
    inherit routes;
  };
in
{
  # Let the gateway start and stop exactly one unit, and nothing else.
  #
  # polkit rather than sudo or a setuid helper: the rule names the unit and the
  # user, so the grant cannot be widened by an argument. If the gateway is ever
  # compromised, what it gained is the ability to toggle a game server.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "valheim.service" &&
          subject.user == "homelab-gateway") {
        return polkit.Result.YES;
      }
    });
  '';

  users.users.homelab-gateway = {
    isSystemUser = true;
    group = "homelab-gateway";
  };
  users.groups.homelab-gateway = { };

  # Wildcard certificate for the whole naming scheme.
  #
  # DNS-01 rather than HTTP-01, for two reasons that both matter here: a wildcard
  # can only be issued over DNS-01 at all, and DNS-01 needs no inbound port, so
  # the certificate renews even though nothing published reaches this board from
  # the internet. The zone lives in Cloudflare, so lego talks to their API with a
  # scoped token -- Zone:DNS:Edit on this zone only, nothing else.
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "alvesdelima.lucas45@gmail.com";
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme-cloudflare.env".path;
      # Cloudflare publishes fast; the check is what makes renewals reliable.
      dnsPropagationCheck = true;

      # 160 hours of validity instead of 90 days.
      #
      # "shortlived" is Let's Encrypt's six-day profile. The point is blast
      # radius: a private key copied off this board is worthless within a week,
      # with no revocation to distribute and no CRL for anyone to fetch -- the
      # certificate simply stops being trusted. That is the whole reason to
      # accept everything below.
      #
      # It is otherwise identical to their "tlsserver" profile, which means two
      # differences from the classic certificates: no Subject Common Name (the
      # names live only in the SAN extension, which every current TLS client
      # already reads) and at most 25 names. This certificate carries two.
      profile = "shortlived";

      # Renewal cadence, stated explicitly because it is now load-bearing.
      #
      # null makes lego renew with --dynamic: below a ten-day lifetime it
      # renews once half the validity is gone, so roughly every 80 hours. That
      # number has to clear a hard limit -- Let's Encrypt allows 5 certificates
      # per exact set of names per 7 days, refilling one per 34 hours, with no
      # override available. At 80 hours we spend about 2.1 per week against a
      # budget of 5. Pinning validMinDays above the six-day lifetime instead --
      # 30, the value this option used to default to -- would renew on every
      # daily run, 7 per week, and issuance would fail from day three on.
      #
      # The cost of the whole arrangement is margin: a broken renewal now takes
      # TLS down in about three days rather than two months. Since renewal
      # depends on the Cloudflare API, revoking or expiring the DNS token is
      # enough to start that clock.
      validMinDays = null;
    };

    certs.${domain} = {
      inherit domain;
      extraDomainNames = [ "*.${domain}" ];
      # The gateway reads the certificate; nothing else needs to.
      group = "homelab-gateway";
    };
  };

  # CAA is the other half of this, and it does not live here.
  #
  # The DNS token above can edit records in the zone, which is exactly what is
  # needed to pass DNS-01 -- and exactly what someone who steals the token would
  # use to have a certificate issued for these names behind our backs. Revoking
  # the token does not undo a certificate that was already issued.
  #
  # A CAA record at h.lalvesl.com closes that. With accounturi= it names the one
  # ACME account allowed to issue here, so a stolen token is no longer enough:
  # the thief would also need this board's ACME account key, which never leaves
  # /var/lib/acme. Scoped at h.lalvesl.com rather than the apex, so the rest of
  # lalvesl.com stays unconstrained.
  #
  # It is a DNS record, so it cannot be declared in this repository -- run
  # ../caa-records.sh against the board and paste what it prints into
  # Cloudflare. The script explains the ordering, which matters: accounturi=
  # cannot be set before the account it names exists.
  sops.templates."acme-cloudflare.env" = {
    content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder."acme/cloudflare-dns-token"}
    '';
    mode = "0400";
  };

  systemd.services.homelab-gateway = {
    description = "Pingora edge gateway";
    wantedBy = [ "multi-user.target" ];
    # The certificate has to exist before the TLS listener can bind; the gateway
    # panics rather than silently falling back to plaintext.
    after = [
      "network.target"
      "acme-finished-${domain}.target"
    ];
    wants = [ "acme-finished-${domain}.target" ];

    serviceConfig = {
      ExecStart = "${lib.getExe gateway} ${gatewayConfig}";
      Environment = [ "RUST_LOG=info" ];

      # The control panel shells out to systemctl, which reaches systemd over a
      # unix socket -- hence AF_UNIX below, and systemd on PATH here.
      ExecSearchPath = "${pkgs.systemd}/bin";

      # A static user rather than DynamicUser: the ACME certificate directory is
      # owned by a group, and a per-boot dynamic identity cannot be a stable
      # member of one.
      User = "homelab-gateway";
      Group = "homelab-gateway";

      # Ports 80 and 443 without running as root.
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

      Restart = "on-failure";
      RestartSec = 2;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        # systemctl talks to systemd over a unix socket.
        "AF_UNIX"
      ];
      MemoryMax = "256M";
      CPUWeight = 180; # everything interactive passes through here
    };
  };

  # nginx serves Nextcloud and nothing else, on loopback, behind the gateway.
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    appendConfig = ''
      worker_processes 2;
    '';
    virtualHosts."cloud.${domain}".listen = [
      {
        addr = "127.0.0.1";
        port = nextcloudPort;
      }
    ];
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # The cloudflared module only supports locally-managed tunnels, configured
  # with a credentials JSON file and an ingress block. A tunnel driven by a
  # dashboard token has no option in the module at all, so it gets its own unit.
  #
  # The token is a bare string in sops; cloudflared wants it as TUNNEL_TOKEN.
  # sops.templates renders the env file with the value substituted at
  # activation, so the assembled file only ever exists in ramfs next to the
  # secrets themselves.
  sops.templates."cloudflared.env" = {
    content = ''
      TUNNEL_TOKEN=${config.sops.placeholder."cloudflared_tunnel_token"}
    '';
    mode = "0400";
  };

  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = { };

  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare tunnel (remotely managed)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "homelab-gateway.service"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe config.services.cloudflared.package)
        "tunnel"
        "--no-autoupdate"
        "--metrics 127.0.0.1:0"
        "run"
      ];
      EnvironmentFile = config.sops.templates."cloudflared.env".path;
      User = "cloudflared";
      Group = "cloudflared";
      Restart = "on-failure";
      RestartSec = 10;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      MemoryMax = "256M";
    };
  };
}
