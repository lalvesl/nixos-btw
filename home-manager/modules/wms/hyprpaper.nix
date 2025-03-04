{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      preload = [
        (builtins.toString ./wall.jpg)
      ];

      wallpaper = [
        "eDP-1,${builtins.toString ./wall.jpg}"
        "HDMI-A-1,${builtins.toString ./wall.jpg}"
      ];
    };
  };
}
