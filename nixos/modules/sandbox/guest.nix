# The sbx guest: one NixOS VM per project for running and hacking on code that
# is not trusted. Built on nixpkgs' qemu-vm.nix (the `nixos-rebuild build-vm`
# machinery) and launched by `sbx` (./sbx.sh).
#
# Disks, both per project and nothing shared with other projects or the host:
#   root  a qcow2 overlay over the read-only base image built here
#         (system.build.sbxImage). Holds the guest's own /nix/store, so what
#         one project builds or downloads never reaches another.
#   home  /home, kept even when the root disk is rebuilt by `sbx --upgrade`
#
# 9p shares the launcher adds:
#   src      the project folder, writable, at /work
#   sbxmeta  read-only: authorized_keys, slot, net, name
#
# Languages and project tools are not here: they come from the project's
# flake.nix (loaded on entry) or `nix shell`. The base has nvim, prebuilt with
# everything it needs (./nvim.nix), and everyday command-line tools.
#
# The guest is the untrusted side. Nothing here is a security boundary; the
# boundary is KVM plus what the host chooses to hand in (see ./default.nix).
{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  sbxAi,
  ...
}:
let
  user = "dev";

  # Plugins that talk to an AI service, left out of the --no-ai variant
  aiPlugins = [
    "claudecode.lua"
    "supermaven.lua"
    "tabby.lua"
  ];
  nvimConfig = lib.cleanSourceWith {
    src = ../../../nvim;
    filter = path: _type: sbxAi || !(builtins.elem (baseNameOf path) aiPlugins);
  };

  # Yanks reach the host clipboard as OSC 52, which Alacritty accepts. Pasting
  # stays on the host side (ctrl+shift+v): Alacritty refuses OSC 52 reads.
  # LazyVim turns unnamedplus off over SSH; it is wanted here.
  nvimClipboard = pkgs.writeText "sbx-clipboard.lua" ''
    local osc52 = require("vim.ui.clipboard.osc52")
    local function paste()
      return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste, ["*"] = paste },
    }
    vim.opt.clipboard = "unnamedplus"
  '';

  mount9p = tag: readOnly: {
    device = tag;
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "msize=${toString config.virtualisation.msize}"
    ]
    ++ lib.optional readOnly "ro";
  };

  sbx-enter = pkgs.writeShellApplication {
    name = "sbx-enter";
    runtimeInputs = with pkgs; [
      coreutils
      config.nix.package
      zsh
    ];
    text = builtins.readFile ./enter.sh;
  };

  # `make | clip`: stdin to the host clipboard, over the terminal
  clip = pkgs.writeShellApplication {
    name = "clip";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      printf '\033]52;c;%s\a' "$(base64 -w0)" >/dev/tty
    '';
  };

  sbx-nvim = import ./nvim.nix {
    inherit lib pkgs;
    ai = sbxAi;
  };

  # Every push URL is rewritten to sbx-no-push://, and git runs this helper for
  # that scheme. Pushing happens from the host; the guest has no credentials
  # to push with anyway, this only makes the refusal explicit.
  git-remote-sbx-no-push = pkgs.writeShellScriptBin "git-remote-sbx-no-push" ''
    echo "sbx: pushing is disabled inside the sandbox; push from the host" >&2
    exit 1
  '';
in
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    inputs.home-manager.nixosModules.home-manager
  ];

  system.stateVersion = "25.05";
  networking.hostName = "sbx";
  time.timeZone = "America/Sao_Paulo";
  documentation.enable = false;
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";

  # The base image: the whole guest closure on an ext4 filesystem, with its
  # Nix database. Each project's root disk is a copy-on-write overlay of it.
  system.build.sbxImage = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit config lib pkgs;
    name = "disk-basic-vm";
    format = "qcow2";
    partitionTableType = "none";
    installBootLoader = false;
    copyChannel = false;
    additionalSpace = "1G";
  };

  virtualisation = {
    # Defaults; `sbx --mem/--cpus` override them per boot
    memorySize = 8192;
    cores = 4;
    # The SPICE display is always attached so `sbx --gui` works on a running
    # VM; the launcher passes `-display none` so no local window ever opens
    graphics = true;
    # The store lives on the root disk, not on a share from the host
    mountHostNixStore = false;
    useNixStoreImage = false;
    writableStore = false;
    msize = 524288;
    # Only the shares the launcher adds itself; no exchange dir with the host
    sharedDirectories = lib.mkForce { };
    # The launcher picks a tap (or none, for --offline) per boot
    qemu.networkingOptions = lib.mkForce [ ];
    fileSystems = {
      # The overlay is bigger than the base image's filesystem
      "/".autoResize = true;
      # Formatted by the launcher; mounted in the initrd so user activation
      # finds it
      "/home" = {
        device = "/dev/disk/by-label/sbx-home";
        fsType = "ext4";
        neededForBoot = true;
      };
      "/work" = mount9p "src" false;
      "/mnt/sbx/meta" = mount9p "sbxmeta" true;
    };
  };
  # The base image comes with its database already filled in
  systemd.services.register-nix-paths.enable = false;

  networking = {
    useDHCP = false;
    usePredictableInterfaceNames = false;
    enableIPv6 = false;
    # Inside the guest a firewall protects nothing, and it would get in the way
    # of forwarded ports. Isolation is enforced on the host.
    firewall.enable = false;
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  # Per-boot wiring from the host's meta share: network slot and SSH key.
  # Runs before any SSH session can start.
  systemd.services.sbx-setup = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = with pkgs; [
      coreutils
      iproute2
      util-linux
      rsync
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      meta=/mnt/sbx/meta
      install -D -m 0644 "$meta/authorized_keys" /run/sbx/authorized_keys

      slot=$(cat "$meta/slot")
      if [ "$(cat "$meta/net")" = online ]; then
        ip link set eth0 up
        ip addr replace "10.77.$slot.2/30" dev eth0
        ip route replace default via "10.77.$slot.1"
      fi

      install -d -o ${user} -g users /var/cache/sbx

      # Neovim config, mirrored from the repo every boot (a plugin file removed
      # there goes here too). lazy.nvim writes its state files into it, so it
      # is a copy rather than a store symlink.
      home=/home/${user}
      install -d -o ${user} -g users "$home"
      runuser -u ${user} -- mkdir -p "$home/.config/nvim"
      runuser -u ${user} -- rsync -r --delete --chmod=u+w \
        --exclude=lazy-lock.json --exclude=lazyvim.json \
        ${nvimConfig}/ "$home/.config/nvim/"
      runuser -u ${user} -- install -D -m 0644 ${nvimClipboard} "$home/.config/nvim/plugin/sbx-clipboard.lua"
    '';
  };

  # SSH over vsock port 22: the only way the host gets in. Declared here rather
  # than left to systemd-ssh-generator, which runs before the vsock transport
  # is loaded and so never sees it.
  boot.kernelModules = [ "vmw_vsock_virtio_transport" ];
  boot.kernelParams = [ "systemd.ssh_auto=no" ];
  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [
      {
        addr = "127.0.0.1";
        port = 22;
      }
    ];
    authorizedKeysFiles = [ "/run/sbx/authorized_keys" ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ user ];
    };
  };
  systemd.sockets.sbx-ssh = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "vsock::22" ];
    socketConfig.Accept = true;
  };
  systemd.services."sbx-ssh@" = {
    after = [
      "sbx-setup.service"
      "sshd-keygen.service"
    ];
    requires = [ "sbx-setup.service" ];
    serviceConfig = {
      ExecStart = "-${config.services.openssh.package}/bin/sshd -i -f /etc/ssh/sshd_config";
      StandardInput = "socket";
      StandardError = "journal";
    };
  };

  users.mutableUsers = false;
  # The key comes per boot from the host (authorized_keys on the meta share)
  users.allowNoPasswordLogin = true;
  users.users.${user} = {
    isNormalUser = true;
    # Same uid as the host user, so files on the 9p project share line up
    uid = 1000;
    extraGroups = [
      "wheel"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
  };
  # Root inside the guest buys the code nothing it could not already do from
  # the VM, so it is not worth a password prompt
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;
  # Prebuilt binaries from anywhere (release tarballs, npm and pip wheels) run
  programs.nix-ld.enable = true;
  environment.enableAllTerminfo = true;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Same nixpkgs as the host, already in the base image. No global registry:
    # it is a download on every lookup, and `nixpkgs` is all it would add.
    settings.flake-registry = "";
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  environment.sessionVariables = {
    # Rust builds on the home disk: the 9p project share is slow for them
    CARGO_TARGET_DIR = "/home/${user}/.cache/cargo-target";
    # For GUI apps started from SSH, against the `sbx --gui` session
    WAYLAND_DISPLAY = "wayland-1";
    DISPLAY = ":0";
  };

  environment.systemPackages =
    with pkgs;
    [
      sbx-enter
      clip
      sbx-nvim
      git-remote-sbx-no-push

      git
      lazygit
      tmux
      htop
      strace
      file
      tree
      jq
      fzf
      wget
      curl
      unzip
      rsync

      # The Rust rewrites of the classics
      ripgrep
      fd
      bat
      eza
      sd
      dust
      procs
      bottom
      delta
      tokei
      hyperfine
      xh
    ]
    ++ lib.optional sbxAi (import ../../pkgs/claude-code.nix { inherit pkgs; });

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = {
      imports = [
        ../home/zsh.nix
        ../home/git.nix
      ];
      home.username = user;
      home.homeDirectory = "/home/${user}";
      home.stateVersion = "25.05";

      # Commits carry the host identity (git.nix); pushes are refused, for
      # every kind of remote URL
      programs.git.settings.url."sbx-no-push://".pushInsteadOf = [
        "https://"
        "http://"
        "ssh://"
        "git://"
        "git@"
        "file://"
        "/"
        "."
      ];

      programs.zoxide.enable = true;

      # A prompt that cannot be mistaken for the host's: a red segment with the
      # project name, and the directory in yellow instead of blue
      programs.zsh.initContent = lib.mkAfter ''
        SBX_PROJECT=$(cat /mnt/sbx/meta/name 2>/dev/null || echo sbx)
        prompt_context() {
          prompt_segment red white "sbx $SBX_PROJECT"
        }
        prompt_dir() {
          prompt_segment yellow black "$(_compressed_dir)"
        }
      '';
    };
  };

  # `sbx --gui`: a sway session on the SPICE display, started on demand.
  # Software rendering, since the display is plain virtio-vga.
  programs.sway.enable = true;
  hardware.graphics.enable = true;
  security.pam.services.sbx-gui.startSession = true;
  systemd.services.sbx-gui = {
    after = [
      "systemd-user-sessions.service"
      "systemd-logind.service"
    ];
    wants = [ "systemd-logind.service" ];
    conflicts = [ "getty@tty1.service" ];
    environment = {
      WLR_RENDERER = "pixman";
      WLR_NO_HARDWARE_CURSORS = "1";
    };
    serviceConfig = {
      ExecStart = "${config.programs.sway.package}/bin/sway";
      User = user;
      PAMName = "sbx-gui";
      UtmpIdentifier = "%n";
      UtmpMode = "user";
      TTYPath = "/dev/tty1";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      StandardInput = "tty-fail";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
