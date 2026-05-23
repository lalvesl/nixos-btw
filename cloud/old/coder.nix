# with import <nixpkgs> { };
# docker run -v nix_cache:/nix -v home_cache:/home/$USER nix-shell:0.0.1
{
  pkgs ? import <nixpkgs> {
    # config = {
    #   allowUnfree = true;
    # };
  },
}:
let
  user = builtins.toString (builtins.getEnv "USER");
  wayland_display = builtins.toString (builtins.getEnv "$WAYLAND_DISPLAY");
  nonRootShadowSetup =
    {
      user,
      uid,
      gid ? uid,
    }:
    with pkgs;
    [
      (writeTextDir "etc/shadow" ''
        root:!x:::::::
        ${user}:!:::::::
      '')
      (writeTextDir "etc/passwd" ''
        root:x:0:0::/root:${runtimeShell}
        ${user}:x:${toString uid}:${toString gid}::/home/${user}:/bin/bash
      '')
      (writeTextDir "etc/group" ''
        root:x:0:
        ${user}:x:${toString gid}:
      '')
      (writeTextDir "etc/gshadow" ''
        root:x::
        ${user}:x::
      '')
    ];
  homeConfig = pkgs.stdenv.mkDerivation {
    name = "app-folder";
    src = ./.;
    installPhase = ''
      mkdir -p $out
    '';
    buildPhase = ''
      mkdir -p $out/home/${user}/.config
      cp -r ./home-manager $out/home/${user}/.config
      cp -r ./nvim $out/home/${user}/.config
      cat $out/home/${user}/.config/home-manager/modules/mod.nix | grep -v wms > $out/home/${user}/.config/home-manager/modules/mod2.nix
      mv $out/home/${user}/.config/home-manager/modules/mod2.nix $out/home/${user}/.config/home-manager/modules/mod.nix
    '';
  };
  entrypoint_file = pkgs.writeTextDir "entrypoint.sh" ''
    #!/bin/sh
    set -e

    # Copy default Nix store if /nix is empty
    if [ ! "$(ls -A /nix)" ]; then
      echo "Initializing /nix store..."
      cp -a /nix_default/. /nix/
    fi

    # Copy home directory if empty
    if [ ! "$(ls -A /home/${user})" ]; then
      echo "Initializing home directory..."
      cp -a /home_default/. /home/${user}/
      chown -R ${user}:${user} /home/${user}
    fi

    exec "$@"
  '';
in
# homeConfig = pkgs.writeTextDir "home/coder/.config/nixpkgs/home.nix" ''
#   { config, pkgs, ... }: {
#     home.username = "coder";
#     home.homeDirectory = "/home/coder";
#     programs.bash.enable = true;
#     home.stateVersion = "23.11";
#   }
# '';

pkgs.dockerTools.buildLayeredImage {
  name = "nix-shell";
  tag = "0.0.1";
  created = "now";

  contents =
    with pkgs;
    [
      kubectl
      kubernetes-helm
      yq
      jq
      bash
      coreutils
      python3
      moreutils
      git
      cacert
      curl
      getent
      shadow
      sudo
      gnutar
      nix
      docker
      docker-compose
      systemd
      python3
      neovim
      nodejs_22
      cargo
      bacon
      home-manager
      nixd
      nixfmt-rfc-style
      homeConfig
      entrypoint_file
    ]
    ++ nonRootShadowSetup {
      uid = 1000;
      user = "${user}";
    };

  fakeRootCommands = ''
    mkdir -p ./var/tmp/
    chmod 1777 ./var/tmp/
    HOME=/home/${user} home-manager --config /home/${user}/.config/nixpkgs/home.nix switch

    mkdir -p /nix_default
    cp -a /nix/. /nix_default/

    mkdir -p /home_default/${user}
    cp -a /home/${user}/. /home_default/${user}/
    chown -R ${user}:${user} /home_default/${user}
  '';

  config = {
    Cmd = [ "/bin/zsh" ];
    Entrypoint = [
      "/bin/sh"
      "/entrypoint.sh"
    ];
    WorkingDir = "/home/${user}";
    User = "${user}";
    Env = [
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_PAGER=cat"
      "WAYLAND_DISPLAY=${wayland_display}"
    ];
    Volumes = {
      "/run/user/1000/${wayland_display}" = { };
    };
    HostConfig = {
      Binds = [
        "/run/user/1000/${wayland_display}:/run/user/1000/${wayland_display}"
      ];
    };
  };
}
