{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
        Enable = "Source,Sink,Media,Socket";
        Disable = "Headset,Sink";
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;
}
