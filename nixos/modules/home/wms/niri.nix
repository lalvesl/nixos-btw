{ ... }:
{
  xdg.configFile."niri/config.kdl".text = ''
    output "eDP-1" {
        mode "1920x1080@60.052"
        position x=1920 y=0
        scale 1.0
    }

    output "HDMI-A-1" {
        mode "1920x1080@60.000"
        position x=0 y=0
        scale 1.0
    }

    input {
        keyboard {
            xkb {
                layout "br"
            }
        }
        touchpad {
            tap
            dwt
            scroll-method "two-finger"
            click-method "clickfinger"
        }
        focus-follows-mouse
    }

    environment {
        XCURSOR_SIZE "16"
        XCURSOR_THEME "Adwaita"
        XDG_SCREENSHOTS_DIR "/home/lalvesl/screens"
    }

    layout {
        gaps 16
        default-column-width { proportion 1.0; }
        border {
            off
        }
        focus-ring {
            off
        }
    }

    window-rule {
        opacity 0.99
    }

    window-rule {
        match is-focused=false
        opacity 0.75
    }

    spawn-at-startup "waybar"
    spawn-at-startup "swaybg" "-i" "${./wall.jpg}" "-m" "fill"
    spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
    spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"

    binds {
        Mod+Return { spawn "alacritty"; }
        Mod+Space { spawn "alacritty"; }
        Mod+Q { close-window; }
        Mod+N { spawn "nautilus"; }
        Mod+F { toggle-window-floating; }
        Mod+G { maximize-column; }
        Mod+F11 { fullscreen-window; }
        Mod+D { spawn "sh" "-c" "rofi -show drun"; }
        Mod+V { spawn "sh" "-c" "cliphist list | rofi -dmenu | cliphist decode | wl-copy"; }
        Mod+X { spawn "swaylock"; }
        Mod+S { spawn "sh" "-c" "pgrep wlsunset && pkill wlsunset || wlsunset -t 3000 -T 3001"; }
        Mod+B { spawn "sh" "-c" "pkill -SIGUSR1 waybar"; }
        Mod+W { spawn "sh" "-c" "pkill -SIGUSR2 waybar"; }

        Mod+H { spawn "sh" "-c" "niri msg action focus-column-left || niri msg action focus-column-last"; }
        Mod+L { spawn "sh" "-c" "niri msg action focus-column-right || niri msg action focus-column-first"; }
        Mod+K { focus-window-up; }
        Mod+J { focus-window-down; }

        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+J { move-window-down; }

        Mod+I { consume-window-into-column; }
        Mod+O { expel-window-from-column; }

        Mod+Ctrl+H { set-column-width "-60"; }
        Mod+Ctrl+Shift+H { set-column-width "-300"; }
        Mod+Ctrl+L { set-column-width "+60"; }
        Mod+Ctrl+Shift+L { set-column-width "+300"; }
        Mod+Ctrl+K { set-window-height "-60"; }
        Mod+Ctrl+Shift+K { set-window-height "-300"; }
        Mod+Ctrl+J { set-window-height "+60"; }
        Mod+Ctrl+Shift+J { set-window-height "+300"; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+0 { focus-workspace 10; }

        Mod+Shift+1 { move-window-to-workspace 1; }
        Mod+Shift+2 { move-window-to-workspace 2; }
        Mod+Shift+3 { move-window-to-workspace 3; }
        Mod+Shift+4 { move-window-to-workspace 4; }
        Mod+Shift+5 { move-window-to-workspace 5; }
        Mod+Shift+6 { move-window-to-workspace 6; }
        Mod+Shift+7 { move-window-to-workspace 7; }
        Mod+Shift+8 { move-window-to-workspace 8; }
        Mod+Shift+9 { move-window-to-workspace 9; }
        Mod+Shift+0 { move-window-to-workspace 10; }

        Mod+Alt+J { spawn "sh" "-c" "niri msg action focus-workspace-down || niri msg action focus-workspace 1"; }
        Mod+Alt+K { spawn "sh" "-c" "niri msg action focus-workspace-up || niri msg action focus-workspace-down"; }
        Mod+Alt+Shift+J { move-window-to-workspace-down; }
        Mod+Alt+Shift+K { move-window-to-workspace-up; }

        Print { spawn "sh" "-c" "grim -g \"$(slurp)\" - | swappy -f -"; }

        XF86AudioRaiseVolume { spawn "sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"; }
        Shift+XF86AudioRaiseVolume { spawn "sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+"; }
        XF86AudioLowerVolume { spawn "sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"; }
        Shift+XF86AudioLowerVolume { spawn "sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"; }
        XF86AudioMute { spawn "sh" "-c" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute { spawn "sh" "-c" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
        Ctrl+XF86AudioRaiseVolume { spawn "sh" "-c" "pamixer --source @DEFAULT_SOURCE@ -i 10"; }
        Ctrl+XF86AudioLowerVolume { spawn "sh" "-c" "pamixer --source @DEFAULT_SOURCE@ -d 10"; }

        XF86MonBrightnessUp { spawn "sh" "-c" "brightnessctl s 2%+"; }
        Shift+XF86MonBrightnessUp { spawn "sh" "-c" "brightnessctl s 20%+"; }
        XF86MonBrightnessDown { spawn "sh" "-c" "brightnessctl s 2%-"; }
        Shift+XF86MonBrightnessDown { spawn "sh" "-c" "brightnessctl s 20%-"; }

        XF86AudioNext { spawn "sh" "-c" "playerctl next"; }
        XF86AudioPause { spawn "sh" "-c" "playerctl play-pause"; }
        XF86AudioPlay { spawn "sh" "-c" "playerctl play-pause"; }
        XF86AudioPrev { spawn "sh" "-c" "playerctl previous"; }
    }
  '';
}
