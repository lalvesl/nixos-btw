{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity.overrideAttrs (_: {
    src = pkgs.fetchurl {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz";
      sha256 = "sha256-UjKkBI/0+hVoXZqYG6T7pXPil/PvybdvY455S693VyU=";
    };
  });
  claude-code-src = builtins.fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/3cc73775ecceb02a798519a5527f4eb400c8c8e4.tar.gz";
    sha256 = "sha256:0qjs9qzg9i8javqdv0k4pcz2zrcpypx2p61k3d0wfqnbg1s5q6nn";
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
