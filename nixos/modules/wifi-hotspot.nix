{
  lib,
  pkgs,
  ...
}:
let
  # `wifi-hotspot` shares the current Wi-Fi connection through a second network
  # made by the same card (client and access point at once). Turn off to drop
  # the command.
  wifiHotspot = true;

  ssid = "lalvesl-hotspot";
  country = "BR";

  hotspot = pkgs.writeShellApplication {
    name = "wifi-hotspot";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gnused
      iw
      linux-wifi-hotspot # create_ap: virtual interface, hostapd, dnsmasq, NAT
      networkmanager
    ];
    runtimeEnv = {
      HOTSPOT_SSID = ssid;
      HOTSPOT_COUNTRY = country;
    };
    text = builtins.readFile ./wifi-hotspot.sh;
  };
in
{
  environment.systemPackages = lib.mkIf wifiHotspot [ hotspot ];
}
