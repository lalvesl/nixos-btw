{ ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin = "9 13 -10 18";

        modules-left = [ "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "custom/mem"
          "cpu"
          "temperature"
          "backlight"
          "battery"
        ];

        "niri/workspaces" = {
          disable-scroll = true;
        };

        "clock" = {
          interval = 1;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format = "{:%a; %d %b, %I:%M:%S %p}";
        };

        "pulseaudio" = {
          reverse-scrolling = 1;
          format = "{volume}% {icon}  {format_source}";
          format-muted = "󰖁  {format_source}";
          format-source = "{volume}% 󰍬";
          format-source-muted = "󰍭";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
            headphone = "󰋋";
            headset = "󰋎";
            phone = "󰏲";
            portable = "󰏲";
            car = "󰄋";
          };
          on-click = "pavucontrol";
          min-length = 15;
        };

        "custom/mem" = {
          format = "{} 󰍛";
          interval = 3;
          exec = "free -h | awk '/Mem:/{printf $3}' | sed 's/i//'";
          tooltip = false;
        };

        "cpu" = {
          interval = 1;
          format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7} {usage:>2}% {avg_frequency:1.2f}G 󰻠";
          format-icons = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
        };

        "temperature" = {
          thermal-zone = 0;
          hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-critical = "{temperatureC}°C {icon}";
          format-icons = [ "󱃃" "󰔏" "󱃂" ];
          tooltip = false;
        };

        "backlight" = {
          device = "intel_backlight";
          format = "{percent}% {icon}";
          format-icons = [ "󰃞" "󰃟" "󰃠" ];
          min-length = 7;
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% 󰂄";
          format-plugged = "{capacity}% 󰚥";
          format-alt = "{time} {icon}";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          on-update = "$HOME/.config/waybar/scripts/check_battery.sh";
        };
      };
    };

    style = ''
      * {
          border: none;
          border-radius: 0;
          font-family: JetBrains Mono, Symbols Nerd Font Mono;
          font-weight: bold;
          font-size: 13px;
          min-height: 20px;
      }

      window#waybar {
          background: transparent;
      }

      window#waybar.hidden {
          opacity: 0.2;
      }

      #workspaces {
          margin-right: 8px;
          border-radius: 10px;
          background: #383c4a;
          padding: 0 4px;
      }

      #workspaces button {
          color: #7c818c;
          background: transparent;
          padding: 5px 8px;
          font-size: 14px;
          transition: none;
          box-shadow: none;
          text-shadow: none;
      }

      #workspaces button:hover {
          color: #383c4a;
          background: #7c818c;
          border-radius: 8px;
          transition: none;
      }

      #workspaces button.active {
          background: #4e5263;
          color: #ffffff;
          border-radius: 8px;
      }

      #clock {
          padding: 0 16px;
          border-radius: 10px;
          color: #ffffff;
          background: #383c4a;
      }

      #pulseaudio,
      #custom-mem,
      #cpu,
      #temperature,
      #backlight,
      #battery {
          margin-right: 6px;
          padding: 0 14px;
          border-radius: 10px;
          color: #ffffff;
          background: #383c4a;
      }

      #pulseaudio.muted {
          background: #90b1b1;
          color: #2a5c45;
      }

      #temperature.critical {
          background: #eb4d4b;
      }

      #battery.charging {
          color: #ffffff;
          background: #26A65B;
      }

      #battery.warning:not(.charging) {
          background: #ffbe61;
          color: black;
      }

      #battery.critical:not(.charging) {
          background: #f53c3c;
          color: #ffffff;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      @keyframes blink {
          to {
              background: #ffffff;
              color: #000000;
          }
      }
    '';
  };
}
