{
  config,
  inputs,
  pkgs,
  ...
}:
let
  antigravity-nix-src = fetchTarball {
    url = "https://github.com/jacopone/antigravity-nix/archive/65aeafed6d9290cb73a6124bcc7b37fc1246a22d.tar.gz";
    sha256 = "1ghx7b2432xfw31if75fb37qg184dl73g1sx9bx6c8a58m5zdqnb";
  };
  latest_antigravity = pkgs.callPackage "${antigravity-nix-src}/pkgs/google-antigravity-ide.nix" { };
  latest_antigravity-cli = pkgs.callPackage "${antigravity-nix-src}/pkgs/cli.nix" { };
  latest_claude-code = import ../pkgs/claude-code.nix { inherit pkgs; };
in
{
  imports = [ inputs.ai-memory.nixosModules.default ];

  # Shared long-term memory for coding agents (hardened systemd service on
  # 127.0.0.1:49374, data in /var/lib/ai-memory). Loopback-only, so no auth.
  services.ai-memory.enable = true;

  # Wire Claude Code to ai-memory on every activation (switch and boot).
  # Both commands are idempotent: an unchanged config is a no-op, so a backup
  # (`*.bak-<ts>`) is only written when the package path changes. Hooks point
  # at the current store path, which stays alive as part of this generation.
  home-manager.users.lalvesl =
    { lib, ... }:
    {
      home.activation.aiMemory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        aiMemory=${config.services.ai-memory.package}
        # Staged hook scripts keep the store's read-only mode, so a re-run
        # could not overwrite them without this.
        if [ -d "$HOME/.local/share/ai-memory/hooks" ]; then
          run chmod -R u+w "$HOME/.local/share/ai-memory/hooks"
        fi
        run "$aiMemory/bin/ai-memory" install-mcp --client claude-code --apply \
          || warnEcho "ai-memory: install-mcp failed"
        # The binary does not probe share/ for its hook bundle; point at it.
        run "$aiMemory/bin/ai-memory" install-hooks --agent claude-code --apply \
          --hooks-dir "$aiMemory/share/ai-memory/hooks" \
          || warnEcho "ai-memory: install-hooks failed"
      '';
    };

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

      zed-editor
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
