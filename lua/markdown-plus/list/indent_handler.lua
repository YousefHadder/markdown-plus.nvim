-- Indent/outdent handlers for list management
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local handler_utils = require("markdown-plus.list.handler_utils")

local M = {}

---Set module configuration (reserved for future use; keeps facade propagation uniform)
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg) -- luacheck: no unused args
  -- Indent handler currently delegates all config-dependent behavior to handler_utils.
  -- This stub keeps the set_config interface uniform across all handler sub-modules.
end

---Handle Tab key for indentation
---@return nil
function M.handle_tab()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, fall through to default Tab behavior
    local key = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Increase indentation
  local indent_size = vim.fn.shiftwidth()

  local new_indent = list_info.indent .. string.rep(" ", indent_size)
  local content = shared.extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)
  utils.set_cursor(row, col + indent_size)
end

---Handle Shift+Tab key for outdentation
---@return nil
function M.handle_shift_tab()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not a list line, fall through to default Shift+Tab behavior
    local key = vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Decrease indentation
  local indent_size = vim.fn.shiftwidth()

  -- Can't outdent if already at root level
  if #list_info.indent == 0 then
    return
  end

  local remove = math.min(indent_size, #list_info.indent)
  local new_indent = list_info.indent:sub(1, #list_info.indent - remove)
  local content = shared.extract_list_content(current_line, list_info)
  local new_marker = list_info.full_marker

  if handler_utils.smart_outdent_enabled() then
    local target_indent = #new_indent
    local lines, _ = handler_utils.get_context_lines(row, handler_utils.CONTEXT_LOOKBACK, 0)
    local parent_list = shared.find_parent_list_at_indent(row, target_indent, lines)
    if parent_list then
      new_marker = parser.get_next_marker(parent_list)
      if list_info.checkbox then
        new_marker = new_marker .. " [" .. list_info.checkbox .. "]"
      end
    end
  end

  local new_line = new_indent .. new_marker .. " " .. content

  utils.set_line(row, new_line)

  -- Adjust cursor position
  local marker_delta = #new_marker - #list_info.full_marker
  local new_col = math.max(0, col - remove + marker_delta)
  utils.set_cursor(row, new_col)
end

return M
