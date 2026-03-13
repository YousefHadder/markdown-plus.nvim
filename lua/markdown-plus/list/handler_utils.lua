-- Shared utilities for list input handlers
local shared = require("markdown-plus.list.shared")

local M = {}

local CONTEXT_LOOKBACK = 100
local CONTEXT_LOOKAHEAD = 100
local MAX_LAST_ITEM_LOOKAHEAD = 50

---@type markdown-plus.InternalConfig
local config = {}

---Set module configuration
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg)
  config = cfg or {}
end

---Check whether smart outdent behavior is enabled (default: true)
---@return boolean
function M.smart_outdent_enabled()
  return not (config.list and config.list.smart_outdent == false)
end

---Build the prefix string for a new list item (indent + marker + optional checkbox)
---@param indent string Indentation string
---@param marker string List marker (e.g., "-", "1.", "a)")
---@param checkbox string|nil Non-nil if the list uses checkboxes (value ignored — new items always start unchecked)
---@return string prefix The constructed list item prefix
function M.build_list_prefix(indent, marker, checkbox)
  local prefix = indent .. marker .. " "
  if checkbox then
    prefix = prefix .. "[ ] "
  end
  return prefix
end

---Find parent list item by looking upward from current line
---@param current_row number Current row number (1-indexed)
---@param current_line string Current line content
---@return table|nil, number|nil List info and row number of parent, or nil if not found
function M.find_parent_list_item(current_row, current_line)
  local start_row = math.max(1, current_row - shared.MAX_PARENT_LOOKBACK)
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, current_row, false)
  local line_map = {}
  for idx, line in ipairs(lines) do
    line_map[start_row + idx - 1] = line
  end

  return shared.find_parent_list_item(current_line, current_row, line_map)
end

---Get a windowed line map keyed by absolute row number
---@param start_row number
---@param end_row number
---@return table<number, string>
function M.get_line_window(start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local line_map = {}
  for idx, line in ipairs(lines) do
    line_map[start_row + idx - 1] = line
  end
  return line_map
end

---Get context lines around a row as an absolute-row map
---@param row number
---@param lookback number|nil Lookback lines (default: 100)
---@param lookahead number|nil Lookahead lines (default: 100)
---@return table<number, string> lines_by_row
---@return number line_count
function M.get_context_lines(row, lookback, lookahead)
  lookback = lookback or CONTEXT_LOOKBACK
  lookahead = lookahead or CONTEXT_LOOKAHEAD
  local line_count = vim.api.nvim_buf_line_count(0)
  local start_row = math.max(1, row - lookback)
  local end_row = math.min(line_count, row + lookahead)
  local lines_by_row = M.get_line_window(start_row, end_row)
  return lines_by_row, line_count
end

-- Export constants for sub-modules that need them
M.CONTEXT_LOOKBACK = CONTEXT_LOOKBACK
M.CONTEXT_LOOKAHEAD = CONTEXT_LOOKAHEAD
M.MAX_LAST_ITEM_LOOKAHEAD = MAX_LAST_ITEM_LOOKAHEAD

return M
