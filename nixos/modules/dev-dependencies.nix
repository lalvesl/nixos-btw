{ pkgs, ... }:
let
  latest_antigravity = pkgs.antigravity;
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
      latest_claude-code
    ];
}
