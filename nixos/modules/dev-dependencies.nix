{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity.overrideAttrs (_: {
    src = pkgs.fetchurl {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz";
      sha256 = "sha256-UjKkBI/0+hVoXZqYG6T7pXPil/PvybdvY455S693VyU=";
    };
  });
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/a020d210d15807efebdf18aa1ff84f893956b714.tar.gz";
    sha256 = "sha256:1kdkxb8awmbbnm9jayz0s1pq5p8zgsw9p8i6rjkv2kd4qca73z69";
  };
  latest_claude-code = pkgs.callPackage "${claude-code-src}/package.nix" { };
in
{
  environment.systemPackages =
    with pkgs;
    [
      gnumake
      gcc
      nodejs
      cargo
      rustup
      # python
      # (python3.withPackages (ps: with ps; [ requests ]))

      # CLI utils
      vim
      neovim
      helix
      nixd # lsp for nix laguage
      nixfmt
      fzf
      tmux
      # nvtop
      nvtopPackages.full
      jq
      jq-zsh-plugin
      inotify-tools

      # DBs
      dbeaver-bin

      # Why?, i don't now, i not use, I USE NVIM BTW
      vscodium

    ]
    ++ [
      #Yep, this day has come
      latest_antigravity
      latest_claude-code
    ];
}
