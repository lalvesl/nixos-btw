{ config, ... }:
{
  programs.niri = {
    enable = true;
    settings = {
      outputs."eDP-1" = {
        mode = { width = 1920; height = 1080; refresh = 60.052; };
        position = { x = 1920; y = 0; };
        scale = 1.0;
      };
      outputs."HDMI-A-1" = {
        mode = { width = 1920; height = 1080; refresh = 60.0; };
        position = { x = 0; y = 0; };
        scale = 1.0;
      };

      input = {
        keyboard.xkb.layout = "br";
        touchpad.natural-scroll = false;
      };

      layout = {
        gaps = 16;
        border = {
          width = 2;
          active-color = "#33ccffee";
          inactive-color = "#595959aa";
        };
      };

      spawn-at-startup = [
        { command = [ "waybar" ]; }
        { command = [ "swaybg" "-i" (builtins.toString ./wall.jpg) "-m" "fill" ]; }
        { command = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
        { command = [ "wl-paste" "--type" "image" "--watch" "cliphist" "store" ]; }
      ];

      binds = with config.lib.niri.actions; let
        sh = cmd: spawn [ "sh" "-c" cmd ];
      in {
        "Mod+Return" = spawn "alacritty";
        "Mod+Space" = spawn "alacritty";
        "Mod+Q" = close-window;
        "Mod+N" = spawn "nautilus";
        "Mod+F" = toggle-window-floating;
        "Mod+D" = sh "wofi --show drun";
        "Mod+V" = sh "cliphist list | wofi --dmenu | cliphist decode | wl-copy";
        "Mod+X" = spawn "swaylock";
        "Mod+B" = sh "pkill -SIGUSR1 waybar";
        "Mod+W" = sh "pkill -SIGUSR2 waybar";

        "Mod+H" = focus-column-left;
        "Mod+L" = focus-column-right;
        "Mod+K" = focus-window-up;
        "Mod+J" = focus-window-down;

        "Mod+Shift+H" = move-column-left;
        "Mod+Shift+L" = move-column-right;
        "Mod+Shift+K" = move-window-up;
        "Mod+Shift+J" = move-window-down;

        "Mod+Ctrl+H" = set-column-width "-60";
        "Mod+Ctrl+Shift+H" = set-column-width "-300";
        "Mod+Ctrl+L" = set-column-width "+60";
        "Mod+Ctrl+Shift+L" = set-column-width "+300";
        "Mod+Ctrl+K" = set-window-height "-60";
        "Mod+Ctrl+Shift+K" = set-window-height "-300";
        "Mod+Ctrl+J" = set-window-height "+60";
        "Mod+Ctrl+Shift+J" = set-window-height "+300";

        "Mod+1" = focus-workspace 1;
        "Mod+2" = focus-workspace 2;
        "Mod+3" = focus-workspace 3;
        "Mod+4" = focus-workspace 4;
        "Mod+5" = focus-workspace 5;
        "Mod+6" = focus-workspace 6;
        "Mod+7" = focus-workspace 7;
        "Mod+8" = focus-workspace 8;
        "Mod+9" = focus-workspace 9;
        "Mod+0" = focus-workspace 10;

        "Mod+Shift+1" = move-window-to-workspace 1;
        "Mod+Shift+2" = move-window-to-workspace 2;
        "Mod+Shift+3" = move-window-to-workspace 3;
        "Mod+Shift+4" = move-window-to-workspace 4;
        "Mod+Shift+5" = move-window-to-workspace 5;
        "Mod+Shift+6" = move-window-to-workspace 6;
        "Mod+Shift+7" = move-window-to-workspace 7;
        "Mod+Shift+8" = move-window-to-workspace 8;
        "Mod+Shift+9" = move-window-to-workspace 9;
        "Mod+Shift+0" = move-window-to-workspace 10;

        "Mod+Alt+L" = focus-workspace-down;
        "Mod+Alt+H" = focus-workspace-up;
        "Mod+Alt+Shift+L" = move-window-to-workspace-down;
        "Mod+Alt+Shift+H" = move-window-to-workspace-up;

        "Print" = sh ''grim -g "$(slurp)" - | swappy -f -'';

        "XF86AudioRaiseVolume" = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+";
        "Shift+XF86AudioRaiseVolume" = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+";
        "XF86AudioLowerVolume" = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-";
        "Shift+XF86AudioLowerVolume" = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-";
        "XF86AudioMute" = sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "Ctrl+XF86AudioRaiseVolume" = sh "pamixer --source @DEFAULT_SOURCE@ -i 10";
        "Ctrl+XF86AudioLowerVolume" = sh "pamixer --source @DEFAULT_SOURCE@ -d 10";

        "XF86MonBrightnessUp" = sh "brightnessctl s 2%+";
        "Shift+XF86MonBrightnessUp" = sh "brightnessctl s 20%+";
        "XF86MonBrightnessDown" = sh "brightnessctl s 2%-";
        "Shift+XF86MonBrightnessDown" = sh "brightnessctl s 20%-";

        "XF86AudioNext" = sh "playerctl next";
        "XF86AudioPause" = sh "playerctl play-pause";
        "XF86AudioPlay" = sh "playerctl play-pause";
        "XF86AudioPrev" = sh "playerctl previous";
      };
    };
  };
}
