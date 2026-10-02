{ pkgs, ... }:
let
  antigravity-nix-src = fetchTarball {
    url = "https://github.com/jacopone/antigravity-nix/archive/cd0cda807c66d30ae347b8b61ec146f60f695b8f.tar.gz";
    sha256 = "1zmm4s1na3q2hx71gpmx99zkzqyzjaq06vz6sn6awaji635z4fcj";
  };
  latest_antigravity = pkgs.callPackage "${antigravity-nix-src}/pkgs/google-antigravity-ide.nix" { };
  latest_antigravity-cli = pkgs.callPackage "${antigravity-nix-src}/pkgs/cli.nix" { };
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/82ee196c58667c5f76fdd4ac646e2e2c05778e86.tar.gz";
    sha256 = "0ir73lmhwr4fcjrm6ppq11abgr2c6bhz520gwbdha1nmsn5ddmki";
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

      fastfetch
      file
      tree
      wget
      git
      fastfetch
      ripgrep
      sd
      fd
      htop
      nix-index
      unzip
      scrot
      ffmpeg

      # DBs
      dbeaver-bin

      # Why?, i don't now, i not use, I USE NVIM BTW
      vscodium

    ]
    ++ [
      #Yep, this day has come
      latest_antigravity
      latest_antigravity-cli
      latest_claude-code
    ];
}
