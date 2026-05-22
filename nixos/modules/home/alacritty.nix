{ ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.7;
      window.decorations = "None";

      font = {
        size = 13.0;
        normal = {
          family = "JetBrains Mono";
          style = "Bold";
        };
      };

      colors.primary.background = "#1d2021";
    };
  };
}
