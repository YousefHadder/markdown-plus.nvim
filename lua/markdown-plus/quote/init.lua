-- Quote management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

--- Setup quote module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

--- Enable quote features for current buffer
---@return nil
function M.enable()
  M.setup_keymaps()
end

--- Set up keymaps for quote management
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("ToggleQuote"),
      fn = {
        M.toggle_quote_line,
        M.toggle_quote,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mq", "<leader>mq" },
      desc = "Toggle blockquote",
    },
  })
end

function M.toggle_quote()
  local selection = utils.get_visual_selection(false) -- Don't need column info
  for row = selection.start_row, selection.end_row do
    M.toggle_quote_on_line(row)
  end
end

-- Toggle blockquote on current line
function M.toggle_quote_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  M.toggle_quote_on_line(row)
end

-- Toggle blockquote on a specific line
---@param line_num number 1-indexed line number
---@return nil
function M.toggle_quote_on_line(line_num)
  local line = utils.get_line(line_num)
  if line == "" then
    -- Create a new blockquote and enter insert mode at the end
    utils.set_line(line_num, "> ")
    vim.api.nvim_win_set_cursor(0, { line_num, 2 })
    vim.cmd("startinsert!")
    return
  end
  -- Check if the line starts with '>'
  if line:match("^%s*>") then
    -- Remove blockquote and any following space
    line = line:gsub("^%s*>%s?", "", 1)
  else
    -- Add blockquote
    line = "> " .. line
  end
  utils.set_line(line_num, line)
end

return M
