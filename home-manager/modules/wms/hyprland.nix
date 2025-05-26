{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      "$mainMod" = "SUPER";

      monitor = [
        "eDP-1,1920x1080@60.05200,0x0,1"
        "HDMI-A-1,1920x1080@60.00000,-1920x0,1"
      ];

      # Error, hyprland does not support
      # vfr = "no";
      # renderer = "egl";
      # vulkan = "no";

      ### Programns
      "$terminal" = "alacritty";
      "$fileManager" = "range";
      "$menu" = "wofi --show drun";

      env = [
        "XCURSOR_SIZE,20"
        "HYPRCURSOR_SIZE,20"
        "XDG_SCREENSHOTS_DIR,~/screens"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      general = {
        gaps_in = 5;
        gaps_out = "15 2 2 2";
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true;

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;

        layout = "dwindle";
        # no_cursor_warps = false;
      };

      decoration = {
        rounding = 10;

        # Change transparency of focused and unfocused windows
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
          # new_optimizations = true;
        };

        # drop_shadow = true;
        # shadow_range = 4;
        # shadow_render_power = 3;
        # "col.shadow" = "rgba(1a1a1aee)";
      };

      animations = {
        enabled = true;
        # bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        # bezier = "myBezier, 0.33, 0.82, 0.9, -0.08";

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          # "windows,     1, 7,  myBezier"
          # "windowsOut,  1, 7,  default, popin 80%"
          # "border,      1, 10, default"
          # "borderangle, 1, 8,  default"
          # "fade,        1, 7,  default"
          # "workspaces,  1, 6,  default"

          #Default options
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

      # Ref https://wiki.hyprland.org/Configuring/Workspace-Rules/
      # "Smart gaps" / "No gaps when only"
      # uncomment all if you wish to use that.
      # workspace = w[tv1], gapsout:0, gapsin:0
      # workspace = f[1], gapsout:0, gapsin:0
      # windowrulev2 = bordersize 0, floating:0, onworkspace:w[tv1]
      # windowrulev2 = rounding 0, floating:0, onworkspace:w[tv1]
      # windowrulev2 = bordersize 0, floating:0, onworkspace:f[1]
      # windowrulev2 = rounding 0, floating:0, onworkspace:f[1]

      # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
      dwindle = {
        pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true; # you probably want this
      };

      master = {
        new_status = "master";
      };

      # debug = {
      #   disable_logs = true;
      #   damage_tracking = "full";
      #   enable_stdout_logs = true;
      # };

      misc = {
        force_default_wallpaper = -1;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        enable_swallow = true;
        render_ahead_of_time = false;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "br";
        # kb_variant = "lang";
        # kb_model =
        # kb_options = "grp:caps_toggle";
        # kb_rules =

        follow_mouse = 1;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
          natural_scroll = false;
        };

      };

      gestures = {
        workspace_swipe = false;
        # workspace_swipe = true;
        # workspace_swipe_fingers = 3;
        # workspace_swipe_invert = false;
        # workspace_swipe_distance = 200;
        # workspace_swipe_forever = true;
      };

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      # windowrule = [
      #   "float, ^(imv)$"
      #   "float, ^(mpv)$"
      # ];

      exec-once = [
        "waybar"
        "hyprpaper"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      bind = [
        "$mainMod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        "$mainMod, Return, exec, alacritty"
        "$mainMod, Space, exec, alacritty"
        "$mainMod, Q, killactive,"
        # "$mainMod, M, exit,"
        "$mainMod, E, exec, dolphin"
        "$mainMod, F, togglefloating,"
        "$mainMod, D, exec, wofi --show drun"
        "$mainMod, P, pseudo, # dwindle"
        # "$mainMod, J, togglesplit, # dwindle"

        # Move focus with mainMod + arrow keys
        "$mainMod, h,  movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k,    movefocus, u"
        "$mainMod, j,  movefocus, d"

        # Moving windows
        "$mainMod SHIFT, h,  swapwindow, l"
        "$mainMod SHIFT, l, swapwindow, r"
        "$mainMod SHIFT, k,    swapwindow, u"
        "$mainMod SHIFT, j,  swapwindow, d"

        # Window resizing                     X  Y
        "$mainMod CTRL, h,  resizeactive, -60 0"
        "$mainMod CTRL SHIFT, h,  resizeactive, -300 0"
        "$mainMod CTRL, l, resizeactive,  60 0"
        "$mainMod CTRL SHIFT, l, resizeactive,  300 0"
        "$mainMod CTRL, k,    resizeactive,  0 -60"
        "$mainMod CTRL SHIFT, k,    resizeactive,  0 -300"
        "$mainMod CTRL, j,  resizeactive,  0  60"
        "$mainMod CTRL SHIFT, j,  resizeactive,  0  300"

        # Switch workspaces with mainMod + [0-9]
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

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
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

        # Switch workspaces with vim arrows
        "$mainMod Alt, l, workspace, e+1"
        "$mainMod Alt, h, workspace, e-1"

        "$mainMod Alt Shift, l, movetoworkspacesilent, e+1"
        "$mainMod Alt Shift, h, movetoworkspacesilent, e-1"

        # Keyboard backlight
        # "$mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%"
        # "$mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-"

        # Configuration files
        # "$mainMod SHIFT, N, exec, alacritty -e sh -c \"rb\""
        # "$mainMod SHIFT, C, exec, alacritty -e sh -c \"conf\""
        # "$mainMod SHIFT, H, exec, alacritty -e sh -c \"nvim ~/nix/home-manager/modules/wms/hyprland.nix\""
        # "$mainMod SHIFT, W, exec, alacritty -e sh -c \"nvim ~/nix/home-manager/modules/wms/waybar.nix\""
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"

        # Waybar
        "$mainMod, B, exec, pkill -SIGUSR1 waybar"
        "$mainMod, W, exec, pkill -SIGUSR2 waybar"

        # Disable all effects
        "$mainMod Shift, G, exec, ~/.config/hypr/gamemode.sh "
      ];

      # Mouse bindings,       MOUSE WHY?????
      bindm = [
        "$mainMod CTRL, mouse:272, resizewindow"
        "$mainMod, mouse:272, movewindow"
      ];

      bindel = [
        # Laptop multimedia keys for volume and LCD brightness
        # Audio output
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"
        "Shift, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"
        "Shift, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

        # Audio input
        "Ctrl ,XF86AudioRaiseVolume, exec, pamixer --source @DEFAULT_SOURCE@ -i 10"
        "Ctrl ,XF86AudioLowerVolume, exec, pamixer --source @DEFAULT_SOURCE@ -d 10"
        # "Ctrl ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        # "Ctrl ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

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

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      # Example windowrule v1
      # windowrule = float, ^(kitty)$

      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$

      # Ignore maximize requests from apps. You'll probably like this.
      windowrulev2 = [
        "suppressevent maximize, class:.*"
        # Fix some dragging issues with XWayland
        "nofocus,class:^\$,title:^\$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      # Example windowrule v1
      # windowrule = float, ^(kitty)$

      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$

      # Ignore maximize requests from apps. You'll probably like this.
      # windowrulev2 = "suppressevent maximize, class:.*";

      # Fix some dragging issues with XWayland
      # windowrulev2 = "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0";
      # Move/resize windows with mainMod + LMB/RMB and dragging

    };
  };
}
