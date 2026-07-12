# Nix-built OCI image for the "gamebox" sandbox: Steam + Lutris + Wine/Proton,
# with no filesystem access to the host baked in — isolation happens at the
# `podman run` boundary (see gamebox.nix), not in the image itself.
{ pkgs }:
let
  # lutris' FHS env pulls in openldap transitively; its syncrepl test suite
  # is flaky under the Nix build sandbox (timing-sensitive loopback test).
  # We only need the runtime libs here, so skip its checks.
  pkgs' = pkgs.extend (
    _final: prev: {
      openldap = prev.openldap.overrideAttrs (_: {
        doCheck = false;
      });
    }
  );

  user = "gamer";
  uid = "1000";
  gid = "1000";
  home = "/home/${user}";

  # wine-wow64-staging and winetricks each ship share/applications and
  # share/icons as symlinks rather than plain directories, which the
  # image layer merge can't reconcile. Resolve the collisions ourselves
  # (first listed wins) before handing them to buildLayeredImage.
  #
  # proton-ge-bin is deliberately excluded: its package output is just a
  # placeholder file (not a real directory tree) telling you not to
  # install it into an environment. We only need its store path for
  # PROTONPATH below.
  winingStuff = pkgs'.buildEnv {
    name = "gamebox-wine-stuff";
    paths = with pkgs'; [
      wineWow64Packages.stagingFull
      winetricks
    ];
    ignoreCollisions = true;
  };
in
pkgs'.dockerTools.buildLayeredImage {
  name = "gamebox";
  tag = "latest";
  maxLayers = 120;

  contents = with pkgs'; [
    dockerTools.usrBinEnv
    dockerTools.binSh
    cacert

    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    which
    procps
    shadow

    steam
    lutris
    winingStuff
    proton-ge-bin.steamcompattool

    mesa
    libglvnd
    vulkan-loader
    vulkan-tools

    pipewire
    alsa-lib

    dbus
    fontconfig
    noto-fonts
  ];

  fakeRootCommands = ''
    mkdir -p ${home} tmp
    chmod 1777 tmp

    cat > etc/passwd <<EOF
root:x:0:0:root:/root:/bin/bash
${user}:x:${uid}:${gid}:${user}:${home}:/bin/bash
nobody:x:65534:65534:nobody:/var/empty:/bin/false
EOF

    cat > etc/group <<EOF
root:x:0:
${user}:x:${gid}:
nobody:x:65534:
EOF

    chown -R ${uid}:${gid} ${home}
  '';
  enableFakechroot = true;

  config = {
    User = "${uid}:${gid}";
    WorkingDir = home;
    Env = [
      "HOME=${home}"
      "USER=${user}"
      "PATH=/bin:/usr/bin"
      "SSL_CERT_FILE=${pkgs'.cacert}/etc/ssl/certs/ca-bundle.crt"
      "XDG_DATA_HOME=${home}/.local/share"
      "PROTONPATH=${pkgs'.proton-ge-bin.steamcompattool}"
    ];
    Cmd = [
      "sleep"
      "infinity"
    ];
  };
}
