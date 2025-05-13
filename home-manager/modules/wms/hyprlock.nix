{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      background = [
        {
          monitor = "";
          path = "./wall.jpg"; # Change to your wallpaper path
          blur_size = 8; # Adjust blur intensity
          blur_passes = 3;
          brightness = 0.7; # Optional: Adjust brightness
        }
      ];

      label = [
        {
          text = "$USER"; # Display username
          color = "ffffff"; # White text
          font_size = 30;
          position = {
            x = 0;
            y = -50;
          };
        }
      ];

      input-field = [
        {
          size = {
            width = 300;
            height = 50;
          };
          outline_thickness = 2;
          dots_size = 10;
          dots_spacing = 15;
          dots_center = true;
          fade_on_empty = false;
          position = {
            x = 0;
            y = 50;
          };
        }
      ];
    };
  };
}
