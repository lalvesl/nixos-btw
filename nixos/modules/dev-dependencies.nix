{pkgs, ...}:

{
  environment.systemPackages = with pkgs; [
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
    nixd # lsp for nix laguage
    fzf
    # nvtop
    nvtopPackages.full

    # Why?, i don't now, i not use, I USE NVIM BTW
    vscodium
  ];
}
