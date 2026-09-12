# Valheim dedicated server.
#
# Iron Gate only ships an x86_64 build of the dedicated server, so on the Orange
# Pi 5 the binary runs under box64. That works -- box64 0.4.x recognises
# UnityPlayer.so and MonoBleedingEdge and turns on the memory-ordering
# workarounds x86 code needs on ARM by itself -- but it is emulation, so size
# the expectations accordingly: a handful of players on one world, not a big
# public server.
{
  config,
  lib,
  pkgs,
  nixpkgs,
  ...
}:
let
  cfg = config.services.valheim;

  serverDir = "${cfg.dataDir}/server";
  saveDir = "${cfg.dataDir}/save";

  # Where the start script reads the password from at runtime. A user-supplied
  # passwordFile is handed over by systemd as a credential so it never has to be
  # readable by the service user; the generated fallback lives in the state dir.
  passwordPath =
    if cfg.passwordFile != null then "$CREDENTIALS_DIRECTORY/password" else "${cfg.dataDir}/password";

  # The whole box64 side is taken pre-built for aarch64 instead of being
  # cross-compiled with the rest of the system, because the cross route is
  # unaffordable here: DepotDownloader is a .NET program, and cross-compiling it
  # means building the dotnet SDK from source (~100 derivations). libpulseaudio
  # drags in glib and gobject-introspection. Everything below substitutes
  # straight from cache.nixos.org, so the x86_64 build host never runs an
  # aarch64 compiler.
  native = import nixpkgs {
    system = "aarch64-linux";
    config = { };
    overlays = [ ];
  };

  x86 = import nixpkgs {
    system = "x86_64-linux";
    config = { };
    overlays = [ ];
  };

  # nixpkgs' box64 installs the emulator and nothing else. Upstream also ships
  # x86_64 builds of libgcc_s and libstdc++ under x64lib/, and they are not
  # optional: UnityPlayer.so needs libgcc_s.so.1 and the crossplay plugin
  # libparty.so needs both, and box64 has no native wrapper for either.
  box64X64Libs = pkgs.runCommandLocal "box64-x64lib" { } ''
    mkdir -p "$out/lib"
    cp -R ${native.box64.src}/x64lib/. "$out/lib/"
    chmod -R u+w "$out/lib"
  '';

  # The crossplay plugin libparty.so calls into libogg without listing it as a
  # dependency: on the Ubuntu box Iron Gate builds it on, libogg is in scope
  # anyway because libpulse pulls in libsndfile. nixpkgs' client-only
  # libpulseaudio does not, and box64's native libogg wrapper is no way out --
  # it leaves ogg_stream_pageout_fill unimplemented, which is one of the symbols
  # the plugin needs. So hand box64 a real x86_64 libogg to emulate. References
  # are nuked so the x86_64 glibc does not follow it into an aarch64 closure;
  # box64 wraps libc itself, so the library never looks for one.
  x64ExtraLibs =
    pkgs.runCommandLocal "valheim-x64-extra-libs"
      {
        nativeBuildInputs = with pkgs.buildPackages; [
          patchelf
          nukeReferences
        ];
      }
      ''
        mkdir -p "$out/lib"
        cp ${x86.libogg}/lib/libogg.so.0 "$out/lib/"
        chmod u+w "$out/lib/libogg.so.0"
        patchelf --remove-rpath "$out/lib/libogg.so.0"
        nuke-refs "$out/lib/libogg.so.0"
      '';

  # Native aarch64 libraries that box64 substitutes for the x86_64 ones the game
  # asks for. libc, libm, libpthread, librt, libdl and libanl all come from
  # glibc; libgcc_s and libatomic from the gcc runtime; libpulse* is what the
  # Unity player and the crossplay plugin dlopen for audio.
  nativeLibPath = lib.makeLibraryPath (
    with native;
    [
      glibc
      stdenv.cc.cc.lib
      zlib
      libbsd
      libpulseaudio
    ]
  );

  updateScript = pkgs.writeShellScript "valheim-update" ''
    set -euo pipefail

    if ${lib.getExe native.depotdownloader} \
        -app 896660 \
        -os linux \
        -osarch 64 \
        -dir ${lib.escapeShellArg serverDir} \
        ${lib.optionalString cfg.validate "-validate"}; then
      :
    elif [ -f ${lib.escapeShellArg "${serverDir}/valheim_server.x86_64"} ]; then
      echo "valheim: depot download failed, starting the installed build instead" >&2
    else
      echo "valheim: depot download failed and nothing is installed yet" >&2
      exit 1
    fi

    # Steamworks looks for steamclient.so under ~/.steam/sdk64, not next to the
    # binary. It comes from the Steamworks redistributable depot (1006), which
    # DepotDownloader pulls in alongside the game depot.
    ln -sfn ${lib.escapeShellArg "${serverDir}/linux64/steamclient.so"} \
      ${lib.escapeShellArg "${cfg.dataDir}/.steam/sdk64/steamclient.so"}
  '';

  passwordInitScript = pkgs.writeShellScript "valheim-password-init" ''
    set -eu
    if [ ! -s ${lib.escapeShellArg "${cfg.dataDir}/password"} ]; then
      umask 077
      head -c 16 /dev/urandom | base32 | tr -d '=' | cut -c1-16 \
        > ${lib.escapeShellArg "${cfg.dataDir}/password"}
      echo "valheim: generated a random server password in ${cfg.dataDir}/password"
    fi
  '';

  startScript = pkgs.writeShellScript "valheim-server" ''
    set -euo pipefail

    args=(
      -nographics
      -batchmode
      -name ${lib.escapeShellArg cfg.serverName}
      -world ${lib.escapeShellArg cfg.worldName}
      -port ${toString cfg.port}
      -public ${if cfg.public then "1" else "0"}
      -savedir ${lib.escapeShellArg saveDir}
      ${lib.optionalString cfg.crossplay "-crossplay"}
      ${lib.escapeShellArgs cfg.extraArgs}
    )

    if [ -s "${passwordPath}" ]; then
      args+=(-password "$(cat "${passwordPath}")")
    fi

    exec ${lib.getExe native.box64} \
      ${lib.escapeShellArg "${serverDir}/valheim_server.x86_64"} "''${args[@]}"
  '';
in
{
  options.services.valheim = {
    enable = lib.mkEnableOption "the Valheim dedicated server";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "Valheim";
      description = "Name the server is listed under. The password may not be a substring of it.";
    };

    worldName = lib.mkOption {
      type = lib.types.str;
      default = "Dedicated";
      description = "World to load or create, stored under the save directory.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = "First UDP port. The server also uses the two ports above it.";
    };

    public = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        List the server in the in-game community browser. Needs a reachable
        public address unless {option}`services.valheim.crossplay` is on.
      '';
    };

    crossplay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Join over the PlayFab crossplay backend instead of Steam networking,
        which lets players reach the server without forwarding any port. It
        costs extra CPU on a board that has none to spare, and Steam-only
        clients then have to use the crossplay join code.
      '';
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/valheim-password";
      description = ''
        File holding the server password, at least five characters. Passed to
        the service as a systemd credential, so it does not have to be readable
        by the service user. When left null a random password is generated in
        `password` under the state directory on first start.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "-preset"
        "casual"
      ];
      description = "Extra arguments appended to the server command line.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        BOX64_DYNAREC_STRONGMEM = "3";
      };
      description = ''
        Extra environment for the server process, mainly box64 tuning. box64
        already applies its Unity and Mono presets on its own; raising
        `BOX64_DYNAREC_STRONGMEM` trades speed for stricter x86 memory ordering
        and is the first thing to try if the world corrupts or players desync.
      '';
    };

    updateOnStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch the current build from Steam before every start. Valheim clients
        refuse to join a server on a different version, so restarting is the
        normal way to take an update.
      '';
    };

    validate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Checksum every already-downloaded file on update. Repairs a corrupted
        install, at the cost of hashing two gigabytes on each start.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the three UDP ports the server listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/valheim";
      description = "State directory holding the game install, the worlds and the password.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "User the server runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "Group the server runs as.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isAarch64;
        message = "services.valheim pins its box64 runtime to aarch64-linux and only works there.";
      }
    ];

    users.users = lib.mkIf (cfg.user == "valheim") {
      valheim = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        description = "Valheim dedicated server";
      };
    };

    users.groups = lib.mkIf (cfg.group == "valheim") { valheim = { }; };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${serverDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${saveDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/.steam 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/.steam/sdk64 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.valheim-update = lib.mkIf cfg.updateOnStart {
      description = "Update the Valheim dedicated server from Steam";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = updateScript;
        WorkingDirectory = cfg.dataDir;
        # The first download is two gigabytes onto an SD card or eMMC.
        TimeoutStartSec = "3h";
        Environment = [
          "HOME=${cfg.dataDir}"
          "DOTNET_CLI_TELEMETRY_OPTOUT=1"
          "DOTNET_NOLOGO=1"
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    systemd.services.valheim = {
      description = "Valheim dedicated server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ] ++ lib.optional cfg.updateOnStart "valheim-update.service";
      wants = [ "network-online.target" ];
      requires = lib.optional cfg.updateOnStart "valheim-update.service";

      # Every start pulls the update service in with it, so a server that
      # crashes on startup would otherwise knock on Steam's door every fifteen
      # seconds forever.
      unitConfig = {
        StartLimitIntervalSec = 600;
        StartLimitBurst = 5;
      };

      serviceConfig = {
        ExecStartPre = lib.optional (cfg.passwordFile == null) passwordInitScript;
        ExecStart = startScript;
        WorkingDirectory = serverDir;
        User = cfg.user;
        Group = cfg.group;
        LoadCredential = lib.optional (cfg.passwordFile != null) "password:${toString cfg.passwordFile}";

        # Valheim saves the world on SIGINT and nothing else. SIGTERM loses
        # everything since the last autosave, and saving a grown world on this
        # board is not instant.
        KillSignal = "SIGINT";
        TimeoutStopSec = 180;
        Restart = "on-failure";
        RestartSec = 15;

        Environment = [
          "SteamAppId=892970"
          "HOME=${cfg.dataDir}"
          "LD_LIBRARY_PATH=${nativeLibPath}"
          "BOX64_LD_LIBRARY_PATH=${x64ExtraLibs}/lib:${box64X64Libs}/lib:${serverDir}/linux64"
          "BOX64_NOBANNER=1"
          # Nothing declares a dependency on libogg, so pull it in by hand and
          # keep box64 from answering with its own incomplete wrapper.
          "BOX64_ADDLIBS=libogg.so.0"
          "BOX64_EMULATED_LIBS=libogg.so.0"
        ]
        ++ lib.mapAttrsToList (name: value: "${name}=${value}") cfg.extraEnvironment;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        # box64 writes the code it generates and then executes it, so the
        # usual MemoryDenyWriteExecute hardening cannot be used here.
        MemoryDenyWriteExecute = false;
      };
    };

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [
      cfg.port
      (cfg.port + 1)
      (cfg.port + 2)
    ];
  };
}
