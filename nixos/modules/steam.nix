{
  pkgs,
  config,
  lib,
  ...
}:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
    ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports for Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports for Local transfers

    # Diablo IV refuses to start unless NVAPI reports driver 582.53 or newer.
    # Under Proton that number comes from dxvk-nvapi, which derives it from the
    # Vulkan driver version as `major * 100 + min(minor, 99)`, so the installed
    # 580.173.02 is reported as 580.99. The GTX 1050 is Pascal and therefore
    # pinned to the 580 LTSB branch (see nvidia.nix), and the minor clamp caps
    # that whole branch at 580.99 — no driver update can ever satisfy the check.
    # Report the version the game asks for; this only changes what NVAPI tells
    # games, not the driver actually in use. Raise it if Blizzard raises the bar.
    # Clamp: https://github.com/jp7677/dxvk-nvapi/blob/master/src/nvapi/nvapi_adapter.cpp
    package = pkgs.steam.override {
      extraEnv.DXVK_NVAPI_DRIVER_VERSION = "58253";
    };
  };

  hardware.graphics = {
    enable32Bit = true; # Crucial for Steam and 32-bit games
  };

  programs.steam.extraCompatPackages = with pkgs; [
    proton-ge-bin
  ];

  environment.systemPackages = with pkgs; [
    protonup-qt
  ];
}
