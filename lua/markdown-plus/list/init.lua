-- List management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")

-- Load sub-modules
local parser = require("markdown-plus.list.parser")
local handlers = require("markdown-plus.list.handlers")
local renumber = require("markdown-plus.list.renumber")
local checkbox = require("markdown-plus.list.checkbox")
local toggle = require("markdown-plus.list.toggle")
local keymaps = require("markdown-plus.list.keymaps")
local autocmds = require("markdown-plus.list.autocmds")

local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

-- Re-export patterns for backwards compatibility
M.patterns = parser.patterns

---Setup list management module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
  -- Pass list-specific config to checkbox module
  checkbox.setup(M.config.list)
  handlers.set_config(M.config)
  renumber.set_html_awareness(utils.is_html_awareness_enabled(M.config))
end

---Enable list features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  M.setup_keymaps()
end

---Set up list keymaps and auto-renumber autocommands for the current buffer
---@return nil
function M.setup_keymaps()
  keymaps.setup_keymaps(M.config)
  autocmds.setup_renumber_autocmds()
end

-- Re-export autocommand lifecycle for backwards compatibility
M.setup_renumber_autocmds = autocmds.setup_renumber_autocmds
M.teardown = autocmds.teardown

-- Re-export functions from sub-modules for backwards compatibility
M.parse_list_line = parser.parse_list_line
M.is_empty_list_item = parser.is_empty_list_item
M.break_out_of_list = handlers.break_out_of_list
M.index_to_letter = parser.index_to_letter
M.next_letter = parser.next_letter
M.create_next_list_item = handlers.create_next_list_item
M.handle_enter = handlers.handle_enter
M.continue_list_content = handlers.continue_list_content
M.handle_tab = handlers.handle_tab
M.handle_shift_tab = handlers.handle_shift_tab
M.handle_backspace = handlers.handle_backspace
M.handle_normal_o = handlers.handle_normal_o
M.handle_normal_O = handlers.handle_normal_O
M.renumber_ordered_lists = renumber.renumber_ordered_lists
M.find_list_groups = renumber.find_list_groups
M.is_list_breaking_line = renumber.is_list_breaking_line
M.renumber_list_group = renumber.renumber_list_group
M.debug_list_groups = renumber.debug_list_groups
M.toggle_checkbox_on_line = checkbox.toggle_checkbox_on_line
M.toggle_checkbox_in_line = checkbox.toggle_checkbox_in_line
M.replace_checkbox_state = checkbox.replace_checkbox_state
M.add_checkbox_to_line = checkbox.add_checkbox_to_line
M.toggle_checkbox_line = checkbox.toggle_checkbox_line
M.toggle_checkbox_range = checkbox.toggle_checkbox_range
M.toggle_checkbox_insert = checkbox.toggle_checkbox_insert
M.get_completion_config = checkbox.get_completion_config
M.toggle_list_line = toggle.toggle_list_line
M.toggle_list_range = toggle.toggle_list_range
M.toggle_list_in_range = toggle.toggle_list_in_range
M.clear_list_in_range = toggle.clear_list_in_range
M.clear_list_line = toggle.clear_list_line
M.clear_list_range = toggle.clear_list_range
M.toggle_list_pick_line = toggle.toggle_list_pick_line
M.toggle_list_pick_range = toggle.toggle_list_pick_range

return M
