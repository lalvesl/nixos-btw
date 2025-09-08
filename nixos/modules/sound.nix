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

  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
            bluetooth_policy.set_policy("volume", "off")
      		'';
    # bluez_monitor.properties = {
    # 	["bluez5.enable-sbc-xq"] = true,
    # 	["bluez5.enable-msbc"] = true,
    # 	["bluez5.enable-hw-volume"] = true,
    # 	["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    # }
  };

  environment.systemPackages = with pkgs; [
    pipewire
    pulseaudio
    pamixer

    playerctl
  ];

}
