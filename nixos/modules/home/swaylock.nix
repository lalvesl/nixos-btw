{ pkgs, ... }:
{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # blur the screen behind
      effect-blur = "8x5";
      effect-vignette = "0.5:0.5";

      # clock
      clock = true;
      timestr = "%H:%M:%S";
      datestr = "%A, %d %B";

      # indicator ring
      indicator = true;
      indicator-radius = 120;
      indicator-thickness = 8;
      indicator-caps-lock = true;

      # fonts
      font = "JetBrains Mono Bold";
      font-size = 28;

      # colors — idle state
      inside-color = "1d202155";
      ring-color = "33ccffcc";
      line-color = "00000000";
      text-color = "ffffffff";
      separator-color = "00000000";

      # colors — verifying
      inside-ver-color = "1d202155";
      ring-ver-color = "33ccffff";
      line-ver-color = "00000000";
      text-ver-color = "ffffffff";

      # colors — wrong password
      inside-wrong-color = "ff000044";
      ring-wrong-color = "ff4444ff";
      line-wrong-color = "00000000";
      text-wrong-color = "ffffffff";

      # colors — cleared
      inside-clear-color = "1d202155";
      ring-clear-color = "33ccff88";
      line-clear-color = "00000000";
      text-clear-color = "ffffffff";

      # key highlight
      key-hl-color = "33ccffcc";
      bs-hl-color = "ff444488";

      show-failed-attempts = true;
      grace = 2;
    };
  };
}
