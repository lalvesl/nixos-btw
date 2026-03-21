{
  services.xserver = {
    enable = true;
    windowManager.herbstluftwm.enable = true;

    xkb = {
      layout = "br";
      variant = "";
    };

    # Enable touchpad support (enabled default in most desktopManager).
    # libinput = {
    #   enable = true;
    #   mouse.accelProfile = "flat";
    #   touchpad.accelProfile = "flat";
    # };

    videoDrivers = [ "nvidia" ];
    deviceSection = ''Option "TearFree" "True"'';
    # displayManager.sddm = {
    #     enable = true;
    #     wayland.enable = true;
    # };
    # desktopManager.gnome.enable = true;
  };
  # TDOO: need to split xserver and displayManager configs
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
}
