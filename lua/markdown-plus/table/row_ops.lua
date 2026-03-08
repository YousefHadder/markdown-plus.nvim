---@module 'markdown-plus.table.row_ops'
---@brief [[
--- Row operations for markdown tables
---
--- Provides operations to add, remove, reorder, or copy rows:
--- - insert_row: Insert a new empty row above or below
--- - delete_row: Delete the current data row
--- - duplicate_row: Duplicate the current row below
--- - move_row_up: Swap row with the one above
--- - move_row_down: Swap row with the one below
---@brief ]]

local M = {}
local utils = require("markdown-plus.utils")

---Insert a row in the table
---@param above boolean If true, insert above current row; otherwise below
---@return boolean success True if row was inserted
function M.insert_row(above)
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  -- Create empty row
  local empty_cells = {}
  for _ = 1, table_info.cols do
    table.insert(empty_cells, "")
  end

  -- Determine insertion position in cells array
  local insert_index
  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    insert_index = 2 -- cells[2] = first data row
  else
    local current_cells_index = row_mapper.pos_row_to_cells_index(pos.row)
    if not current_cells_index then
      utils.notify("Cannot determine insertion position (internal error)", vim.log.levels.ERROR)
      return false
    end
    insert_index = above and current_cells_index or current_cells_index + 1
  end

  table.insert(table_info.cells, insert_index, empty_cells)
  return helpers.format_reparse_and_move(table_info, insert_index, 0)
end

---Delete the current row
---@return boolean success True if row was deleted
function M.delete_row()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot delete header or separator row", vim.log.levels.WARN)
    return false
  end

  if #table_info.cells < 2 then
    utils.notify("Cannot delete the only data row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    utils.notify("Cannot delete separator row (internal error)", vim.log.levels.ERROR)
    return false
  end

  local valid, err = row_mapper.validate_cells_index(cells_index, #table_info.cells)
  if not valid then
    utils.notify("Invalid row index: " .. err, vim.log.levels.ERROR)
    return false
  end

  table.remove(table_info.cells, cells_index)

  local updated = helpers.format_and_reparse(table_info)
  if not updated then
    return false
  end

  local new_row = pos.row
  if new_row > #updated.cells then
    new_row = #updated.cells
  end
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(updated, new_row, pos.col)
  return true
end

---Duplicate the current row
---@return boolean success True if row was duplicated
function M.duplicate_row()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot duplicate separator row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    utils.notify("Invalid row position (internal error)", vim.log.levels.ERROR)
    return false
  end

  local valid, err = row_mapper.validate_cells_index(cells_index, #table_info.cells)
  if not valid then
    utils.notify("Invalid row index: " .. err, vim.log.levels.ERROR)
    return false
  end

  local duplicate_cells = vim.deepcopy(table_info.cells[cells_index])

  local target_cells_index = cells_index + 1
  table.insert(table_info.cells, target_cells_index, duplicate_cells)
  local target_row = row_mapper.cells_index_to_pos_row(target_cells_index)
  return helpers.format_reparse_and_move(table_info, target_row, 0)
end

---Move current row up (swap with row above)
---@return boolean success True if row was moved
function M.move_row_up()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot move header or separator row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  if cells_index <= 2 then
    utils.notify("Cannot move row up - already at top", vim.log.levels.WARN)
    return false
  end

  table_info.cells[cells_index], table_info.cells[cells_index - 1] =
    table_info.cells[cells_index - 1], table_info.cells[cells_index]

  return helpers.format_reparse_and_move(table_info, pos.row - 1, pos.col)
end

---Move current row down (swap with row below)
---@return boolean success True if row was moved
function M.move_row_down()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot move header or separator row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  if cells_index >= #table_info.cells then
    utils.notify("Cannot move row down - already at bottom", vim.log.levels.WARN)
    return false
  end

  table_info.cells[cells_index], table_info.cells[cells_index + 1] =
    table_info.cells[cells_index + 1], table_info.cells[cells_index]

  return helpers.format_reparse_and_move(table_info, pos.row + 1, pos.col)
end

return M
