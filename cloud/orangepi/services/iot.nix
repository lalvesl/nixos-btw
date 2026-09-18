# Home Assistant and the MQTT broker.
#
# Home Assistant is the service most likely to be noticed when the board is
# under load -- a light that takes four seconds to turn on reads as broken -- so
# it gets a CPU weight above everything else here and a memory ceiling generous
# enough that it never has to be the one that yields.
{ config, lib, ... }:
{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
        port = 1883;
        # Anonymous access is off; Home Assistant authenticates like any client.
        settings.allow_anonymous = false;
        users.homeassistant = {
          passwordFile = config.sops.secrets."mosquitto/homeassistant-password".path;
          acl = [ "readwrite #" ];
        };
      }
    ];
  };

  systemd.services.mosquitto.serviceConfig.MemoryMax = lib.mkDefault "128M";

  services.home-assistant = {
    enable = true;
    openFirewall = false; # reached through nginx

    extraComponents = [
      "default_config"
      "mqtt"
      "esphome"
      "met"
      "radio_browser"
      "isal"
    ];

    config = {
      default_config = { };

      homeassistant = {
        name = "Home";
        time_zone = "America/Sao_Paulo";
        unit_system = "metric";
        temperature_unit = "C";
      };

      # Home Assistant sits behind nginx, so it has to be told to believe the
      # forwarded headers -- and to believe them only from the proxy.
      http = {
        server_host = [ "127.0.0.1" ];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
  };

  systemd.services.home-assistant.serviceConfig = {
    MemoryMax = "2G";
    CPUWeight = 200; # highest here: latency is the whole point of the service
  };
}
