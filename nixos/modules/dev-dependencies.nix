{ pkgs, ... }:
let
  unstable_pkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
  unstable = import unstable_pkgs {
    inherit pkgs;
    config.allowUnfree = true;
  };
  latest_antigravity = unstable.antigravity.overrideAttrs (oldAttrs: rec {
    src = unstable.fetchurl {
      # url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.20.6-5891862175809536/linux-x64/Antigravity.tar.gz";
      # sha256 = "sha256-rTgr8yGmIW0H+Vrx9hPgP1oH/fb8ZjK3ac6D2Br91Wc=";
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz";
      sha256 = "sha256-UjKkBI/0+hVoXZqYG6T7pXPil/PvybdvY455S693VyU=";
    };
  });
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
      nixfmt-rfc-style
      fzf
      tmux
      # nvtop
      nvtopPackages.full

      # DBs
      dbeaver-bin

      # Why?, i don't now, i not use, I USE NVIM BTW
      vscodium

    ]
    ++ [
      #Yep, this day has come
      latest_antigravity

    ];
}
