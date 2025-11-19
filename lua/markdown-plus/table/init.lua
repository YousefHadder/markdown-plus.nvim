---@module 'markdown-plus.table'
---@brief [[
--- Table editing module for markdown-plus.nvim
---
--- This module provides comprehensive table editing capabilities including:
--- - Automatic table formatting and alignment
--- - Smart cell navigation
--- - Row and column operations (insert, delete, move)
--- - Table creation and normalization
--- - Advanced features (sorting, CSV conversion, transpose)
---@brief ]]

local M = {}

---Default configuration for table module
---@type markdown-plus.InternalTableConfig
M.defaults = {
  enabled = true,
  auto_format = true,
  default_alignment = "left",
  confirm_destructive = true,
  keymaps = {
    enabled = true,
    prefix = "<leader>t",
    insert_mode_navigation = true,
  },
}

---Current table configuration
---@type markdown-plus.InternalTableConfig
M.config = vim.deepcopy(M.defaults)

---Setup table module with user configuration
---@param opts? markdown-plus.TableConfig User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  if not M.config.enabled then
    return
  end

  -- Register global <Plug> mappings once
  local keymaps = require("markdown-plus.table.keymaps")
  keymaps.register_plug_mappings()
end

---Check if cursor is inside a table
---@return boolean
function M.is_in_table()
  local parser = require("markdown-plus.table.parser")
  return parser.get_table_at_cursor() ~= nil
end

---Format the table at cursor position
---@return boolean success True if table was formatted
function M.format_table()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  formatter.format_table(table_info)
  return true
end

---Normalize a malformed table at cursor position
---This is an alias for format_table() that emphasizes fixing malformed tables
---@return boolean success True if table was normalized
function M.normalize_table()
  return M.format_table()
end

---Create a new table with specified dimensions
---@param rows integer Number of rows (excluding header)
---@param cols integer Number of columns
function M.create_table(rows, cols)
  local creator = require("markdown-plus.table.creator")
  creator.create_table(rows, cols, M.config.default_alignment)
end

---Insert row below current row
---@return boolean success True if row was inserted
function M.insert_row_below()
  local manip = require("markdown-plus.table.manipulation")
  return manip.insert_row(false)
end

---Insert row above current row
---@return boolean success True if row was inserted
function M.insert_row_above()
  local manip = require("markdown-plus.table.manipulation")
  return manip.insert_row(true)
end

---Delete current row
---@return boolean success True if row was deleted
function M.delete_row()
  local manip = require("markdown-plus.table.manipulation")
  return manip.delete_row()
end

---Insert column to the right
---@return boolean success True if column was inserted
function M.insert_column_right()
  local manip = require("markdown-plus.table.manipulation")
  return manip.insert_column(false)
end

---Insert column to the left
---@return boolean success True if column was inserted
function M.insert_column_left()
  local manip = require("markdown-plus.table.manipulation")
  return manip.insert_column(true)
end

---Delete current column
---@return boolean success True if column was deleted
function M.delete_column()
  local manip = require("markdown-plus.table.manipulation")
  return manip.delete_column()
end

---Move to the cell to the left (insert mode navigation)
---@return boolean success True if moved successfully
function M.move_left()
  local nav = require("markdown-plus.table.navigation")
  return nav.move_left()
end

---Move to the cell to the right (insert mode navigation)
---@return boolean success True if moved successfully
function M.move_right()
  local nav = require("markdown-plus.table.navigation")
  return nav.move_right()
end

---Move to the cell above (insert mode navigation)
---@return boolean success True if moved successfully
function M.move_up()
  local nav = require("markdown-plus.table.navigation")
  return nav.move_up()
end

---Move to the cell below (insert mode navigation)
---@return boolean success True if moved successfully
function M.move_down()
  local nav = require("markdown-plus.table.navigation")
  return nav.move_down()
end

---Toggle alignment of current column (left → center → right)
---@return boolean success True if alignment was toggled
function M.toggle_cell_alignment()
  local manip = require("markdown-plus.table.manipulation")
  return manip.toggle_cell_alignment()
end

---Move current row up
---@return boolean success True if row was moved
function M.move_row_up()
  local manip = require("markdown-plus.table.manipulation")
  return manip.move_row_up()
end

---Move current row down
---@return boolean success True if row was moved
function M.move_row_down()
  local manip = require("markdown-plus.table.manipulation")
  return manip.move_row_down()
end

---Clear content of current cell
---@return boolean success True if cell was cleared
function M.clear_cell()
  local manip = require("markdown-plus.table.manipulation")
  return manip.clear_cell()
end

---Move column left
---@return boolean success True if column was moved
function M.move_column_left()
  local manip = require("markdown-plus.table.manipulation")
  return manip.move_column_left()
end

---Move column right
---@return boolean success True if column was moved
function M.move_column_right()
  local manip = require("markdown-plus.table.manipulation")
  return manip.move_column_right()
end

---Transpose table (swap rows and columns)
---@return boolean success True if table was transposed
function M.transpose_table()
  local calc = require("markdown-plus.table.calculator")
  return calc.transpose_table()
end

---Sort table by current column (ascending)
---@return boolean success True if table was sorted
function M.sort_ascending()
  local calc = require("markdown-plus.table.calculator")
  return calc.sort_by_column(true)
end

---Sort table by current column (descending)
---@return boolean success True if table was sorted
function M.sort_descending()
  local calc = require("markdown-plus.table.calculator")
  return calc.sort_by_column(false)
end

---Convert table to CSV format
---@return boolean success True if conversion succeeded
function M.table_to_csv()
  local conv = require("markdown-plus.table.conversion")
  return conv.table_to_csv()
end

---Convert CSV to markdown table
---@return boolean success True if conversion succeeded
function M.csv_to_table()
  local conv = require("markdown-plus.table.conversion")
  return conv.csv_to_table()
end

return M
