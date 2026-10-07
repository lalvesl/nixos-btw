{
  config,
  inputs,
  pkgs,
  ...
}:
let
  antigravity-nix-src = fetchTarball {
    url = "https://github.com/jacopone/antigravity-nix/archive/d76245c033c9a5c2a85750341c568a49db4ac681.tar.gz";
    sha256 = "0cp0rp1kpqhhm1j7fib1c8dign4kzih9whq5kvimc1spfzgwa5ny";
  };
  latest_antigravity = pkgs.callPackage "${antigravity-nix-src}/pkgs/google-antigravity-ide.nix" { };
  latest_antigravity-cli = pkgs.callPackage "${antigravity-nix-src}/pkgs/cli.nix" { };
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/13f3032e7a46582bbd3ed749e25817c7ac584b77.tar.gz";
    sha256 = "1xdyma69xsmhk3162nxs1cdlnndcmk1f66ajhns7lvq0akb0q17b";
  };
  latest_claude-code = pkgs.callPackage "${claude-code-src}/package.nix" { };
in
{
  imports = [ inputs.ai-memory.nixosModules.default ];

  # Shared long-term memory for coding agents (hardened systemd service on
  # 127.0.0.1:49374, data in /var/lib/ai-memory). Loopback-only, so no auth.
  # Agents are wired imperatively, once per user:
  #   ai-memory install-mcp --client claude-code --apply
  #   ai-memory install-hooks --agent claude-code --apply
  services.ai-memory.enable = true;

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
      # CLI for install-mcp/install-hooks and the native hook commands
      config.services.ai-memory.package
    ];
}
