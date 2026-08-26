{ pkgs, ... }:
let
  antigravity-nix-src = fetchTarball {
    url = "https://github.com/jacopone/antigravity-nix/archive/4ac825aac542934e901b9de89332c2021d6de2a6.tar.gz";
    sha256 = "sha256:0yx4ddfpwrpdifcga4gjp74k9h57h3j72wx1cdbq1wc2lhbxrhix";
  };
  latest_antigravity = pkgs.callPackage "${antigravity-nix-src}/pkgs/google-antigravity-ide.nix" { };
  latest_antigravity-cli = pkgs.callPackage "${antigravity-nix-src}/pkgs/cli.nix" { };
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/a96094aad959f52a99e5b59670d8e7ae481d7a81.tar.gz";
    sha256 = "sha256:043i4h37q34qlxhhb2xzvlkl3fvk1kb9ysba7r750j7ran7g0a0w";
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
