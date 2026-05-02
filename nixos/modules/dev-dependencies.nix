{ pkgs, ... }:
let
  unstable_pkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
  unstable = import unstable_pkgs {
    inherit pkgs;
    config.allowUnfree = true;
  };
  latest_antigravity = unstable.antigravity.overrideAttrs (oldAttrs: rec {
    src = unstable.fetchurl {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz";
      sha256 = "sha256-UjKkBI/0+hVoXZqYG6T7pXPil/PvybdvY455S693VyU=";
    };
  });
  claude-code-src = builtins.fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/8bd0a84bcfbd7e76eaa1c3421fc59861eb8a8f24.tar.gz";
    sha256 = "sha256:10svmm63z178fjrkmmh7n1ahxqf9znn6bibk1zdqv8vrzkyrj3vi";
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
      latest_claude-code
    ];
}
