{ config, pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = {
        bg = mkLiteral "#1d2021";
        bg-alt = mkLiteral "#282828";
        fg = mkLiteral "#d4d4d4";
        fg-bright = mkLiteral "#ffffff";
        accent = mkLiteral "#33ccff";
        background-color = mkLiteral "@bg";
        text-color = mkLiteral "@fg";
        border-color = mkLiteral "@accent";
      };
      "window" = {
        width = mkLiteral "600px";
        border = mkLiteral "2px solid";
        border-radius = mkLiteral "12px";
        background-color = mkLiteral "@bg";
        padding = mkLiteral "12px";
      };
      "mainbox" = {
        background-color = mkLiteral "transparent";
        spacing = mkLiteral "8px";
      };
      "inputbar" = {
        background-color = mkLiteral "@bg-alt";
        border-radius = mkLiteral "8px";
        padding = mkLiteral "10px 14px";
        children = map mkLiteral [ "prompt" "entry" ];
      };
      "prompt" = {
        text-color = mkLiteral "@accent";
        padding = mkLiteral "0 10px 0 0";
      };
      "entry" = {
        text-color = mkLiteral "@fg-bright";
        background-color = mkLiteral "transparent";
      };
      "listview" = {
        background-color = mkLiteral "transparent";
        lines = 8;
        scrollbar = false;
        spacing = mkLiteral "4px";
      };
      "element" = {
        padding = mkLiteral "8px 12px";
        border-radius = mkLiteral "8px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
        spacing = mkLiteral "8px";
      };
      "element selected" = {
        background-color = mkLiteral "@bg-alt";
        text-color = mkLiteral "@accent";
      };
      "element-text" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
      };
      "element-icon" = {
        background-color = mkLiteral "transparent";
        size = mkLiteral "24px";
      };
    };
  };
}
