{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity.overrideAttrs (_: {
    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.2.1-5287492581195776/linux-x64/Antigravity.tar.gz";
      sha256 = "sha256-prp3BG+SqhziHYoMZ0lUca9MK+EbpiTl2TWCGWmyCYk=";
    };
    sourceRoot = "Antigravity-x64";
  });
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/e0c8acbcb3690471a2d2d485b03d09e303780932.tar.gz";
    sha256 = "sha256:08zi4rfwr7fch23hyfmdyycbg2qgvgn2pzfhp739niyk9hy0x47a";
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
