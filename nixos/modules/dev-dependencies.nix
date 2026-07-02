{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity;
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/90a137caf9a6d82389c0b26a719e26c4e6707367.tar.gz";
    sha256 = "sha256:1y46wjg9wzwhyg2b13h276xavxwka37rbfscymh1sjchl45qnnvl";
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
