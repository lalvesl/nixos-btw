{ pkgs, ... }:
let
  antigravity-nix-src = fetchTarball {
    url = "https://github.com/jacopone/antigravity-nix/archive/f7cd0ba50f447b1baa88cbd379e3256a92876279.tar.gz";
    sha256 = "1qk8w1lrbgzhg29xwj57gpkzd3301n577y0v3jlfy7l43nczpnmz";
  };
  latest_antigravity = pkgs.callPackage "${antigravity-nix-src}/pkgs/google-antigravity-ide.nix" { };
  latest_antigravity-cli = pkgs.callPackage "${antigravity-nix-src}/pkgs/cli.nix" { };
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/98baea86e15af13581b9859e25857da994419ddd.tar.gz";
    sha256 = "0yijx36hhpp6bh0kqym32slhcl962a46zclfxaf0qflrvqsg71x2";
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
      latest_antigravity-cli
      latest_claude-code
    ];
}
