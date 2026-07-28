{ config, pkgs, ... }:
let
  # Force the external monitor on when it is hotplugged (DRM "change" event).
  # `niri msg` talks to the compositor over the IPC socket pointed to by
  # NIRI_SOCKET (not WAYLAND_DISPLAY). That socket's name contains niri's PID and
  # changes every session, so we discover it with a glob. Without NIRI_SOCKET the
  # command fails with "NIRI_SOCKET is not set", which is why hotplug stopped
  # enabling the second screen.
  niri-hdmi-hotplug = pkgs.writeShellScript "niri-hdmi-hotplug" ''
    # Give niri a moment to detect the new connector. Use an absolute path
    # because udev does not guarantee coreutils on PATH.
    ${pkgs.coreutils}/bin/sleep 2
    sockets=(/run/user/1000/niri.wayland-1.*.sock)
    # No live niri socket (e.g. before login): nothing to do.
    [[ -S ''${sockets[0]} ]] || exit 0
    export NIRI_SOCKET=''${sockets[0]}
    exec ${pkgs.niri}/bin/niri msg output HDMI-A-1 on
  '';
in
{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];
  # Enable nvidia for containers
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
    "/dev/nvidia0";

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # GTX 1050 requires legacy 580.xx driver (595+ dropped support)
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;

    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # The 580 driver fails the atomic modeset when a second display is hotplugged
  # ("Failed to apply atomic modeset. Error code: -11" / "Flip event timeout" /
  # "Failed to initialize semaphore for plane fence"), leaving the external
  # monitor black even though niri enables the output. This is a driver-side VRR
  # bug on the 580 branch; concealing VRR caps avoids the broken code path.
  # Takes effect after a reboot. (Do NOT add nvidia_drm.fbdev=1 — it makes this
  # worse.) https://forums.developer.nvidia.com/t/580-display-engine-timeout-and-atomic-modeset-failure-related-to-vrr-and-tty-switching/373168
  boot.kernelParams = [ "nvidia_modeset.conceal_vrr_caps=1" ];

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", RUN+="${niri-hdmi-hotplug}"
  '';
}
