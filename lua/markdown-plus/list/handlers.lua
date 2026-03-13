-- List input handlers facade — delegates to focused sub-modules
local utils = require("markdown-plus.utils")
local handler_utils = require("markdown-plus.list.handler_utils")
local enter_handler = require("markdown-plus.list.enter_handler")
local indent_handler = require("markdown-plus.list.indent_handler")
local normal_handler = require("markdown-plus.list.normal_handler")

local M = {}

---Set module configuration and propagate to all sub-modules
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg)
  handler_utils.set_config(cfg)
  enter_handler.set_config(cfg)
  indent_handler.set_config(cfg)
  normal_handler.set_config(cfg)
end

---Create a wrapper that skips the handler when inside a code block
---Falls through to default key behavior when in a code block
---@param handler function The original handler function
---@param fallback_key string The key to fall through to (e.g., "<CR>", "<Tab>")
---@return function Wrapped handler (not an expr mapping)
function M.skip_in_codeblock(handler, fallback_key)
  return function()
    if utils.is_in_code_block() then
      -- Feed the original key to get default behavior
      local key = vim.api.nvim_replace_termcodes(fallback_key, true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
      return
    end
    handler()
  end
end

-- Re-export enter handler functions
M.break_out_of_list = enter_handler.break_out_of_list
M.create_next_list_item = enter_handler.create_next_list_item
M.handle_enter = enter_handler.handle_enter
M.continue_list_content = enter_handler.continue_list_content

-- Re-export indent handler functions
M.handle_tab = indent_handler.handle_tab
M.handle_shift_tab = indent_handler.handle_shift_tab

-- Re-export normal handler functions
M.handle_backspace = normal_handler.handle_backspace
M.handle_normal_o = normal_handler.handle_normal_o
M.handle_normal_O = normal_handler.handle_normal_O

return M
