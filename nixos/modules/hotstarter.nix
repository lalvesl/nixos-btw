{ pkgs, ... }:

let
  vmt = "${pkgs.vmtouch}/bin/vmtouch";
  userHome = "/home/lalvesl";

  preloadScript = pkgs.writeShellScript "hotstarter-preload" ''
    touch_path() {
      [ -e "$1" ] && ${vmt} -qt "$1"
    }

    # ── Binaries ────────────────────────────────────────────────
    touch_path ${pkgs.alacritty}/bin/alacritty
    touch_path ${pkgs.alacritty}/lib

    touch_path ${pkgs.zsh}/bin/zsh
    touch_path ${pkgs.zsh}/share/zsh

    # ── Zsh plugins (loaded on every shell spawn) ────────────────
    touch_path ${pkgs.oh-my-zsh}
    touch_path ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions
    touch_path ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting

    # ── Nix CLI + libs ───────────────────────────────────────────
    touch_path ${pkgs.nix}/bin
    touch_path ${pkgs.nix}/lib
    touch_path ${pkgs.nix}/share/nix

    # ── Nix store metadata ───────────────────────────────────────
    touch_path /nix/var/nix/db/db.sqlite
    touch_path /nix/var/nix/db/db.sqlite-shm
    touch_path /nix/store/.links
    touch_path /run/current-system/sw/bin

    # ── User configs (symlinks → nix store; vmtouch follows) ─────
    touch_path ${userHome}/.zshrc
    touch_path ${userHome}/.zshenv
    touch_path ${userHome}/.zsh_history
    touch_path ${userHome}/.config/alacritty
    touch_path ${userHome}/.config/kitty
  '';
in
{
  environment.systemPackages = [ pkgs.vmtouch ];

  systemd.services.hotstarter = {
    description = "Pre-warm frequently used binaries into page cache";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "nix-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = preloadScript;
      # Run at lowest priority — don't compete with boot
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  # Re-warm after suspend — page cache is dropped on resume
  systemd.services.hotstarter-resume = {
    description = "Re-warm page cache after suspend";
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = preloadScript;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
}
