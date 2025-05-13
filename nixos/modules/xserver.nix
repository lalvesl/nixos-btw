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

    videoDrivers = [ "amdgpu" ];
    deviceSection = ''Option "TearFree" "True"'';
    # displayManager.sddm = {
    #     enable = true;
    #     wayland.enable = true;
    # };
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = true;
    # desktopManager.gnome.enable = true;
  };
}
