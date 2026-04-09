return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "BufReadPost",
  init = function()
    vim.keymap.set("i", "<C-g>", function()
      local suggestion = require("copilot.suggestion")
      if suggestion.is_visible() then
        suggestion.accept()
      else
        suggestion.suggest()
      end
    end, { desc = "Copilot: Trigger or Accept Suggestion", noremap = true, silent = true })
  end,
  opts = {
    suggestion = {
      enabled = not vim.g.ai_cmp,
      auto_trigger = true,
      hide_during_completion = vim.g.ai_cmp,
      keymap = {
        accept = false, -- handled by nvim-cmp / blink.cmp
        next = "<M-]>",
        prev = "<M-[>",
      },
    },
    panel = { enabled = false },
    filetypes = {
      markdown = true,
      help = true,
    },
  },
}

-- return {
--   "github/copilot.vim",
--   cmd = "Copilot",
--   event = "InsertEnter",
--   config = function()
--     vim.g.copilot_no_tab_map = true
--     vim.g.copilot_assume_mapped = true
--     vim.api.nvim_set_keymap("i", "<C-g>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
--   end,
-- }
