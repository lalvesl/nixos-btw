{ ... }:
{
  programs.helix = {
    enable = true;

    settings = {
      theme = "gruvbox-transparent";

      editor = {
        line-number = "relative";
        mouse = true;
        true-color = true;
        color-modes = true;
        bufferline = "multiple";
        completion-trigger-len = 1;

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        statusline = {
          left = [ "mode" "spinner" "file-name" "read-only-indicator" "file-modification-indicator" ];
          center = [];
          right = [ "diagnostics" "selections" "position" "position-percentage" "file-encoding" "file-type" ];
          mode = {
            normal = "NORMAL";
            insert = "INSERT";
            select = "SELECT";
          };
        };

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };

        indent-guides = {
          render = true;
          character = "╎";
        };
      };

      keys = {
        normal = {
          space.e = "file_picker_in_current_buffer_directory";
          space.E = "file_picker";

          # keep ctrl+s save like most editors
          C-s = ":w";
          C-q = ":q";
        };
        insert = {
          C-s = [ "normal_mode" ":w" ];
        };
      };
    };

    themes = {
      gruvbox-transparent = {
        inherits = "gruvbox_dark_hard";
        "ui.background" = {};
        "ui.popup" = { bg = "bg0_h"; };
        "ui.window" = { fg = "orange"; };
      };
    };
  };
}
