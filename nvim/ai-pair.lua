local MODELS = {
  GEMINI_2_5_FLASH_PREVIEW = 'gemini-2.5-flash-preview-04-17',
  GEMINI_2_5_PRO_PREVIEW = 'gemini-2.5-pro-preview-03-25',
  GEMINI_2_0_FLASH = 'gemini-2.0-flash',
  GEMINI_2_0_FLASH_LITE = 'gemini-2.0-flash-lite',
  GEMINI_2_0_FLASH_EXP = 'gemini-2.0-flash-exp',
  GEMINI_2_0_FLASH_THINKING_EXP = 'gemini-2.0-flash-thinking-exp-1219',
  GEMINI_1_5_PRO = 'gemini-1.5-pro',
  GEMINI_1_5_FLASH = 'gemini-1.5-flash',
  GEMINI_1_5_FLASH_8B = 'gemini-1.5-flash-8b',
}

return {
  'kiddos/gemini.nvim',
  opts = {
  model_config = {
    completion_delay = 1000,
    model_id = MODELS.GEMINI_1_5_FLASH_8B,
    temperature = 0.2,
    top_k = 20,
    max_output_tokens = 8196,
    response_mime_type = 'text/plain',
  },
  chat_config = {
    enabled = true,
  },
  hints = {
    enabled = false,
    hints_delay = 2000,
    insert_result_key = '<C-g>'
  -- get_prompt = function(node, bufnr)
  --   local code_block = vim.treesitter.get_node_text(node, bufnr)
  --   local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  --   local prompt = "Instruction: Use 1 or 2 sentences to describe what the following {filetype} function does:\n\n"
  --       .. "```{filetype}\n"
  --       ..'{code_block}\n```',
  --   prompt = prompt:gsub('{filetype}', filetype)
  --   prompt = prompt:gsub('{code_block}', code_block)
  --   return prompt
  -- end
  },
  completion = {
    enabled = true,
    blacklist_filetypes = { 'help', 'qf', 'json', 'yaml', 'toml' },
    blacklist_filenames = { '.env' },
    completion_delay = 1000,
    move_cursor_end = false,
    insert_result_key = '<C-g>',
    can_complete = function()
      return vim.fn.pumvisible() ~= 1
    end,
    get_system_text = function()
      return "You are a coding AI assistant that autocomplete user's code."
        .. "\n* Your task is to provide code suggestion at the cursor location marked by <cursor></cursor>."
        .. '\n* Do not wrap your code response in ```'
    end,
    get_prompt = function(bufnr, pos)
      local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      local prompt = 'Below is the content of a %s file `%s`:\n'
          .. '```%s\n%s\n```\n\n'
          .. 'Suggest the most likely code at <cursor></cursor>.\n'
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local line = pos[1]
      local col = pos[2]
      local target_line = lines[line]
      if target_line then
        lines[line] = target_line:sub(1, col) .. '<cursor></cursor>' .. target_line:sub(col + 1)
      else
        return nil
      end
      local code = vim.fn.join(lines, '\n')
      local filename = vim.api.nvim_buf_get_name(bufnr)
      prompt = string.format(prompt, filetype, filename, filetype, code)
      return prompt
    end
  },
  instruction = {
    enabled = true,
    menu_key = '<C-l>',
    prompts = {
      {
        name = 'Unit Test',
        command_name = 'GeminiUnitTest',
        menu = 'Unit Test 🚀',
        get_prompt = function(lines, bufnr)
          local code = vim.fn.join(lines, '\n')
          local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
          local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
              .. 'Objective: Write unit test for the above snippet of code\n'
          return string.format(prompt, filetype, code)
        end,
      },
      {
        name = 'Code Review',
        command_name = 'GeminiCodeReview',
        menu = 'Code Review 📜',
        get_prompt = function(lines, bufnr)
          local code = vim.fn.join(lines, '\n')
          local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
          local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
              .. 'Objective: Do a thorough code review for the following code.\n'
              .. 'Provide detail explaination and sincere comments.\n'
          return string.format(prompt, filetype, code)
        end,
      },
      {
        name = 'Code Explain',
        command_name = 'GeminiCodeExplain',
        menu = 'Code Explain',
        get_prompt = function(lines, bufnr)
          local code = vim.fn.join(lines, '\n')
          local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
          local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
              .. 'Objective: Explain the following code.\n'
              .. 'Provide detail explaination and sincere comments.\n'
          return string.format(prompt, filetype, code)
        end,
      },
    },
  },
  task = {
    enabled = true,
    get_system_text = function()
      return 'You are an AI assistant that helps user write code.\n'
        .. 'Your output should be a code diff for git.'
    end,
    get_prompt = function(bufnr, user_prompt)
      local buffers = vim.api.nvim_list_bufs()
      local file_contents = {}

      for _, b in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(b) then -- Only get content from loaded buffers
          local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
          local filename = vim.api.nvim_buf_get_name(b)
          filename = vim.fn.fnamemodify(filename, ":.")
          local filetype = vim.api.nvim_get_option_value('filetype', { buf = b })
          local file_content = table.concat(lines, "\n")
          file_content = string.format("`%s`:\n\n```%s\n%s\n```\n\n", filename, filetype, file_content)
          table.insert(file_contents, file_content)
        end
      end

      local current_filepath = vim.api.nvim_buf_get_name(bufnr)
      current_filepath = vim.fn.fnamemodify(current_filepath, ":.")

      local context = table.concat(file_contents, "\n\n")
      return string.format('%s\n\nCurrent Opened File: %s\n\nTask: %s',
        context, current_filepath, user_prompt)
    end
  },
   },
dependencies = {
   -- If you want to integrate with nvim-cmp for inline suggestions
   'hrsh7th/nvim-cmp',
   'nvim-treesitter/nvim-treesitter', -- Recommended for better context
},
config = function(_, opts)
  require('gemini').setup(opts)
end
}

--   opts = {
--     model_config = {
--       -- Change to the desired Gemini 1.5 Flash-8B model ID
--       -- Based on the Gemini API documentation, the specific model ID for
--       -- Gemini 1.5 Flash-8B is 'gemini-1.5-flash-8b'.
--       -- Make sure to use the exact model ID provided by Google.
--       model_id = "gemini-1.5-flash-8b",
--       temperature = 0.2,
--       top_k = 20,
--       max_output_tokens = 8196,
--       response_mime_type = 'text/plain',
--     },
--     chat_config = {
--       enabled = true,
--     },
--     hints = {
--       enabled = true,
--       hints_delay = 2000,
--       -- Set the key to trigger hints to '<C-g>' (Ctrl+G)
--       insert_result_key = '<C-g>',
--       -- You can customize the prompt for hints here, if needed
--       -- get_prompt = function(node, bufnr) ... end
--     },
--     completion = {
--       -- This is for inline completion, typically triggered automatically or via nvim-cmp
--       get_system_text = function()
--         return "You are a coding AI assistant that autocomplete user's code." ..
--                "\\n* Your task is to provide code suggestion at the cursor location marked by <cursor></cursor>." ..
--                '\\n* Do not wrap your code response in ```'
--       end,
--       get_prompt = function(bufnr, pos)
--         local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
--         local prompt = 'Below is the content of a %s file `%s`:\\n' ..
--                        '```%s\\n%s\\n```\\n\\n' ..
--                        ' Suggest the most likely code at <cursor></cursor>.\\n'
--         local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
--         local line = pos[1]
--         local col = pos[2]
--         local target_line = lines[line]
--         if target_line then
--           lines[line] = target_line:sub(1, col) .. '<cursor></cursor>' .. target_line:sub(col + 1)
--         else
--           return nil
--         end
--         local code = vim.fn.join(lines, '\\n')
--         local filename = vim.api.nvim_buf_get_name(bufnr)
--         prompt = string.format(prompt, filetype, filename, filetype, code)
--         return prompt
--       end
--     },
--     -- ... other configurations for instruction, task, etc.
--   },
--   dependencies = {
--      -- If you want to integrate with nvim-cmp for inline suggestions
--      'hrsh7th/nvim-cmp',
--      'nvim-treesitter/nvim-treesitter', -- Recommended for better context
--   },
--   config = function(_, opts)
--     require('gemini').setup(opts)
--   end
-- }

