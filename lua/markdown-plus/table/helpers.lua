---@module 'markdown-plus.table.helpers'
---@brief [[
--- Shared helpers for table manipulation sub-modules
---
--- Provides common boilerplate for fetching table info and cursor position,
--- reducing repetition across row_ops, column_ops, and cell_ops modules.
---@brief ]]

local M = {}

---Fetch table info and cursor position, notifying on failure.
---@return table|nil table_info Parsed table information, or nil if not in a table
---@return table|nil pos Cursor position in the table, or nil on failure
function M.get_table_and_pos()
  local parser = require("markdown-plus.table.parser")
  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return nil, nil
  end
  local pos = parser.get_cursor_position_in_table()
  return table_info, pos
end

---Reformat table and re-parse to get updated line numbers.
---@param table_info table The modified table info to format
---@return table|nil table_info The re-parsed table info, or nil on failure
function M.format_and_reparse(table_info)
  local formatter = require("markdown-plus.table.format")
  local parser = require("markdown-plus.table.parser")
  formatter.format_table(table_info)
  return parser.get_table_at_cursor()
end

---Reformat table, re-parse, and move cursor to specified cell.
---@param table_info table The modified table info to format
---@param row integer Target row for cursor
---@param col integer Target column for cursor
---@return boolean success True if cursor was moved successfully
function M.format_reparse_and_move(table_info, row, col)
  local updated = M.format_and_reparse(table_info)
  if not updated then
    return false
  end
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(updated, row, col)
  return true
end

return M
