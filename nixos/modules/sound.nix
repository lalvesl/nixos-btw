{ pkgs, ... }:
{
  services.pulseaudio.enable = false;

  # rtkit is optional but recommended
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire = {
      "context.properties" = {
        "flat-volumes" = true;
      };
    };

    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  #Disabled for testing
  # services.pipewire.wireplumber.extraConfig."51-bluetooth" = {
  #   "monitor.bluez.properties" = {
  #     "bluez5.roles" = [
  #       #Another unecessary roles
  #       # "a2dp_sink" "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"
  #       "a2dp_source"
  #     ];
  #     "bluez5.codecs" = [
  #       "sbc"
  #       "sbc_xq"
  #       "aac"
  #     ];
  #     "bluez5.enable-sbc-xq" = true;
  #     "bluez5.enable-hw-volume" = true;
  #   };
  #   "wireplumber.settings" = {
  #     "bluetooth.autoswitch-to-headset-profile" = false;
  #   };
  # };

  services.pipewire.wireplumber.extraConfig."51-echo-fix" = {
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };

    "monitor.bluez.rules" = [
      {
        matches = [
          # Catches the Echo (and any other BT speaker) as soon as it pairs
          { "device.name" = "~bluez_card.*"; }
        ];
        actions = {
          "update-props" = {
            # Forcefully overrides the broken handshake and locks it as a speaker
            "bluez5.profile" = "a2dp-sink";
            "bluez5.auto-connect" = [ "a2dp_sink" ];
          };
        };
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    pipewire
    pulseaudio
    pamixer

    playerctl
  ];

}
