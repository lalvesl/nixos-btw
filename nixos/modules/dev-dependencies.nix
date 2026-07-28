{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity;
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/0d3cd1d6260b6f0ed232224c274c565407446fa1.tar.gz";
    sha256 = "sha256:1ivvwih3cdypqxwlw3lbpjs2sx01smcf3m838ps328pfl73v4yfd";
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
