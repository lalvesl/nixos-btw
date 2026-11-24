# Neovim for the sbx guest with everything prebuilt: the plugins of ./nvim
# from nixpkgs, every treesitter parser, and the LSPs/formatters Mason would
# otherwise download. Nothing is compiled or fetched inside the VM.
#
# The config is the same as the host's. Two globals switch it over:
#   vim.g.sbx_plugins     lazy.nvim loads plugins from here (config/lazy.lua);
#                         one missing from it is still cloned as usual
#   vim.g.sbx_treesitter  nvim-treesitter install_dir (plugins/sbx.lua)
{
  lib,
  pkgs,
  ai,
}:
let
  vp = pkgs.vimPlugins;
  ts = vp.nvim-treesitter;

  github =
    pname: owner: rev: hash:
    pkgs.vimUtils.buildVimPlugin {
      inherit pname;
      version = builtins.substring 0 7 rev;
      src = pkgs.fetchFromGitHub {
        inherit owner rev hash;
        repo = pname;
      };
    };

  # Keyed by the name lazy.nvim gives each plugin (its repository name).
  # The list is what `require("lazy.core.config").spec.plugins` resolves to.
  plugins = {
    "LazyVim" = vp.LazyVim;
    "SchemaStore.nvim" = vp.SchemaStore-nvim;
    "blink.cmp" = vp.blink-cmp;
    "bufferline.nvim" = vp.bufferline-nvim;
    "catppuccin" = vp.catppuccin-nvim;
    "conform.nvim" = vp.conform-nvim;
    "crates.nvim" = vp.crates-nvim;
    "dashboard-nvim" = vp.dashboard-nvim;
    "dial.nvim" = vp.dial-nvim;
    "friendly-snippets" = vp.friendly-snippets;
    "fzf-lua" = vp.fzf-lua;
    "git.nvim" =
      github "git.nvim" "dinhhuy258" "70ceb406568132aec754b25b46ebda1a05dd46f0"
        "sha256-0MeEfyIMQ7tIm15Mn7wa9273T3V1UoxcAxHErh18IIg=";
    "gitsigns.nvim" = vp.gitsigns-nvim;
    "grug-far.nvim" = vp.grug-far-nvim;
    "inc-rename.nvim" = vp.inc-rename-nvim;
    "incline.nvim" = vp.incline-nvim;
    "lazy.nvim" = vp.lazy-nvim;
    "lazydev.nvim" = vp.lazydev-nvim;
    "lualine.nvim" = vp.lualine-nvim;
    "markdown-preview.nvim" = vp.markdown-preview-nvim;
    "mini.ai" = vp.mini-ai;
    "mini.animate" = vp.mini-animate;
    "mini.bracketed" = vp.mini-bracketed;
    "mini.hipatterns" = vp.mini-hipatterns;
    "mini.icons" = vp.mini-icons;
    "mini.nvim" = vp.mini-nvim;
    "mini.pairs" = vp.mini-pairs;
    "neo-tree.nvim" = vp.neo-tree-nvim;
    "neogen" = vp.neogen;
    "noice.nvim" = vp.noice-nvim;
    "nui.nvim" = vp.nui-nvim;
    "nvim-lint" = vp.nvim-lint;
    "nvim-lsp-endhints" =
      github "nvim-lsp-endhints" "chrisgrieser" "d3b7957d202a07196b1b210750dd6818f10f73ac"
        "sha256-Gqo2p3Xs9F0C4mrG8+g5QfsayTzvM21pemfCiibxrro=";
    "nvim-lspconfig" = vp.nvim-lspconfig;
    "nvim-notify" = vp.nvim-notify;
    "nvim-treesitter" = ts;
    "nvim-treesitter-textobjects" = vp.nvim-treesitter-textobjects;
    "nvim-ts-autotag" = vp.nvim-ts-autotag;
    "outline.nvim" = vp.outline-nvim;
    "persistence.nvim" = vp.persistence-nvim;
    "plenary.nvim" = vp.plenary-nvim;
    "refactoring.nvim" = vp.refactoring-nvim;
    "render-markdown.nvim" = vp.render-markdown-nvim;
    "rustaceanvim" = vp.rustaceanvim;
    "snacks.nvim" = vp.snacks-nvim;
    "solarized-osaka.nvim" = vp.solarized-osaka-nvim;
    "telescope-file-browser.nvim" = vp.telescope-file-browser-nvim;
    "telescope-fzf-native.nvim" = vp.telescope-fzf-native-nvim;
    "telescope.nvim" = vp.telescope-nvim;
    "todo-comments.nvim" = vp.todo-comments-nvim;
    "tokyonight.nvim" = vp.tokyonight-nvim;
    "trouble.nvim" = vp.trouble-nvim;
    "ts-comments.nvim" = vp.ts-comments-nvim;
    "which-key.nvim" = vp.which-key-nvim;
    "zen-mode.nvim" = vp.zen-mode-nvim;
  }
  // lib.optionalAttrs ai {
    "claudecode.nvim" = vp.claudecode-nvim;
    "vim-tabby" = vp.vim-tabby;
  };

  pluginDir = pkgs.linkFarm "sbx-nvim-plugins" plugins;

  # nvim-treesitter's install_dir, filled in advance: every parser nixpkgs
  # builds, and the queries nvim-treesitter would copy next to them
  treesitterDir = pkgs.runCommand "sbx-nvim-treesitter" { } ''
    mkdir -p $out/parser $out/queries
    for grammar in ${lib.concatMapStringsSep " " ts.grammarToPlugin ts.allGrammars}; do
      ln -sf "$grammar"/parser/* $out/parser/
    done
    for queries in ${ts}/runtime/queries/*; do
      ln -s "$queries" $out/queries/
    done
  '';

  # What Mason would install for this config, plus what plugins shell out to
  tools = with pkgs; [
    lua-language-server
    stylua
    selene
    luajitPackages.luacheck
    shellcheck
    shfmt
    typescript-language-server
    vtsls
    tailwindcss-language-server
    vscode-langservers-extracted
    prettier
    pyright
    yaml-language-server
    taplo
    clang-tools
    nixd
    nixfmt
    # markdown-preview runs on node
    nodejs
    git
    curl
    ripgrep
    fd
    fzf
    lazygit
  ];
in
pkgs.runCommand "sbx-nvim" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  makeWrapper ${pkgs.neovim}/bin/nvim $out/bin/nvim \
    --suffix PATH : ${lib.makeBinPath tools} \
    --add-flags "--cmd 'let g:sbx_plugins = \"${pluginDir}\" | let g:sbx_treesitter = \"${treesitterDir}\"'"
''
