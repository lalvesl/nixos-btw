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
