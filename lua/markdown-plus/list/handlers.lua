-- List input handlers facade — delegates to focused sub-modules
local utils = require("markdown-plus.utils")
local handler_utils = require("markdown-plus.list.handler_utils")
local enter_handler = require("markdown-plus.list.enter_handler")
local indent_handler = require("markdown-plus.list.indent_handler")
local normal_handler = require("markdown-plus.list.normal_handler")
local keymap_fallback = require("markdown-plus.keymap_fallback")

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
---
---Inside a code block the key is yielded back to whatever mapping would otherwise have run
---(pairs/completion plugins), falling back to the raw key when there is none. Feeding the
---raw key unconditionally — as this did before — silently disabled every foreign mapping
---for these keys inside fenced code blocks.
---@param handler function The original handler function
---@param lhs string The key this handler is mapped from and yields back (e.g., "<CR>", "<Tab>")
---@param mode? string Mapping mode the key is registered in (defaults to "i")
---@return function Wrapped handler (not an expr mapping)
function M.skip_in_codeblock(handler, lhs, mode)
  return function()
    if utils.is_in_code_block() then
      keymap_fallback.run(mode or "i", lhs)
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
