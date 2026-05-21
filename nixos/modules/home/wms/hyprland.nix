{ ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    configType = "hyprlang";

    settings = {
      "$mainMod" = "SUPER";

      monitor = [
        "eDP-1,1920x1080@60.05200,1920x0,1"
        "HDMI-A-1,1920x1080@60.00000,0x0,1"
      ];

      "$terminal" = "alacritty";
      "$fileManager" = "range";
      "$menu" = "wofi --show drun";

      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
        "XDG_SCREENSHOTS_DIR,~/screens"
      ];

      general = {
        gaps_in = 5;
        gaps_out = "15 2 2 2";
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = true;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.8;

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        enable_swallow = true;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "br";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = false;
        };
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      exec-once = [
        "waybar"
        "hyprpaper"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      bind = [
        "$mainMod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
        "$mainMod, S, exec, hyprshade toggle blue-light-filter"
        "$mainMod, X, exec, hyprlock"
        "$mainMod, Return, exec, alacritty"
        "$mainMod, Space, exec, alacritty"
        "$mainMod, Q, killactive,"
        "$mainMod, N, exec, nautilus"
        "$mainMod, F, togglefloating,"
        "$mainMod, D, exec, wofi --show drun"
        "$mainMod, P, exec, hyprctl dispatch togglefloating && hyprctl dispatch pin"
        "$mainMod, R, togglesplit, # dwindle"
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
        "$mainMod SHIFT, h, swapwindow, l"
        "$mainMod SHIFT, l, swapwindow, r"
        "$mainMod SHIFT, k, swapwindow, u"
        "$mainMod SHIFT, j, swapwindow, d"
        "$mainMod CTRL, h, resizeactive, -60 0"
        "$mainMod CTRL SHIFT, h, resizeactive, -300 0"
        "$mainMod CTRL, l, resizeactive,  60 0"
        "$mainMod CTRL SHIFT, l, resizeactive,  300 0"
        "$mainMod CTRL, k, resizeactive,  0 -60"
        "$mainMod CTRL SHIFT, k, resizeactive,  0 -300"
        "$mainMod CTRL, j, resizeactive,  0  60"
        "$mainMod CTRL SHIFT, j, resizeactive,  0  300"
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
        "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, movetoworkspacesilent, 10"
        "$mainMod Alt, l, workspace, e+1"
        "$mainMod Alt, h, workspace, e-1"
        "$mainMod Alt Shift, l, movetoworkspacesilent, e+1"
        "$mainMod Alt Shift, h, movetoworkspacesilent, e-1"
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mainMod, B, exec, pkill -SIGUSR1 waybar"
        "$mainMod, W, exec, pkill -SIGUSR2 waybar"
        "$mainMod Shift, G, exec, ~/.config/hypr/gamemode.sh"
      ];

      bindm = [
        "$mainMod CTRL, mouse:272, resizewindow"
        "$mainMod, mouse:272, movewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"
        "Shift, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"
        "Shift, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        "Ctrl ,XF86AudioRaiseVolume, exec, pamixer --source @DEFAULT_SOURCE@ -i 10"
        "Ctrl ,XF86AudioLowerVolume, exec, pamixer --source @DEFAULT_SOURCE@ -d 10"
        ",XF86MonBrightnessUp, exec, brightnessctl s 2%+"
        "Shift, XF86MonBrightnessUp, exec, brightnessctl s 20%+"
        ",XF86MonBrightnessDown, exec, brightnessctl s 2%-"
        "Shift, XF86MonBrightnessDown, exec, brightnessctl s 20%-"
      ];

      bindl = [
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPause, exec, playerctl play-pause"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioPrev, exec, playerctl previous"
      ];

      windowrulev2 = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];
    };
  };
}
