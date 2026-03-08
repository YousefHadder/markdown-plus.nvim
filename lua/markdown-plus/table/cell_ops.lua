---@module 'markdown-plus.table.cell_ops'
---@brief [[
--- Cell operations for markdown tables
---
--- Provides in-place cell content and alignment modifications:
--- - clear_cell: Clear the content of the current cell
--- - toggle_cell_alignment: Cycle column alignment (left → center → right)
---@brief ]]

local M = {}
local utils = require("markdown-plus.utils")

---Clear content of the current cell
---@return boolean success True if cell was cleared
function M.clear_cell()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot clear separator row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  table_info.cells[cells_index][pos.col + 1] = ""

  local formatter = require("markdown-plus.table.format")
  formatter.format_table(table_info)
  return true
end

---Toggle alignment of the current column
---Cycles through: left → center → right → left
---@return boolean success True if alignment was toggled
function M.toggle_cell_alignment()
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  local col_index = pos.col + 1
  local current_alignment = table_info.alignments[col_index] or "left"

  local next_alignment
  if current_alignment == "left" then
    next_alignment = "center"
  elseif current_alignment == "center" then
    next_alignment = "right"
  else
    next_alignment = "left"
  end

  table_info.alignments[col_index] = next_alignment

  local formatter = require("markdown-plus.table.format")
  formatter.format_table(table_info)

  utils.notify(string.format("Column alignment: %s", next_alignment), vim.log.levels.INFO)
  return true
end

return M
