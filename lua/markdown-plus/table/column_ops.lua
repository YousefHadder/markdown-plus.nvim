---@module 'markdown-plus.table.column_ops'
---@brief [[
--- Column operations for markdown tables
---
--- Provides operations to add, remove, reorder, or copy columns:
--- - insert_column: Insert a new empty column left or right
--- - delete_column: Delete the current column
--- - duplicate_column: Duplicate the current column
--- - move_column_left: Swap column with the one to the left
--- - move_column_right: Swap column with the one to the right
---@brief ]]

local M = {}

---Insert a column in the table
---@param left boolean If true, insert left of current column; otherwise right
---@return boolean success True if column was inserted
function M.insert_column(left)
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  local insert_col = left and pos.col or pos.col + 1

  for _, row in ipairs(table_info.cells) do
    table.insert(row, insert_col + 1, "")
  end

  table_info.cols = table_info.cols + 1
  table.insert(table_info.alignments, insert_col + 1, "left")

  return helpers.format_reparse_and_move(table_info, pos.row, insert_col)
end

---Delete the current column
---@return boolean success True if column was deleted
function M.delete_column()
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if table_info.cols <= 1 then
    vim.notify("Cannot delete the only column", vim.log.levels.WARN)
    return false
  end

  for _, row in ipairs(table_info.cells) do
    table.remove(row, pos.col + 1)
  end

  table_info.cols = table_info.cols - 1
  table.remove(table_info.alignments, pos.col + 1)

  local updated = helpers.format_and_reparse(table_info)
  if not updated then
    return false
  end

  local new_col = pos.col
  if new_col >= updated.cols then
    new_col = updated.cols - 1
  end
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(updated, pos.row, new_col)
  return true
end

---Duplicate the current column
---@return boolean success True if column was duplicated
function M.duplicate_column()
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  for _, row in ipairs(table_info.cells) do
    local cell_content = row[pos.col + 1] or ""
    table.insert(row, pos.col + 2, cell_content)
  end

  table_info.cols = table_info.cols + 1
  local alignment = table_info.alignments[pos.col + 1] or "left"
  table.insert(table_info.alignments, pos.col + 2, alignment)

  return helpers.format_reparse_and_move(table_info, pos.row, pos.col + 1)
end

---Move column left (swap with column to the left)
---@return boolean success True if column was moved
function M.move_column_left()
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if pos.col == 0 then
    vim.notify("Cannot move column left - already at leftmost position", vim.log.levels.WARN)
    return false
  end

  for _, row in ipairs(table_info.cells) do
    row[pos.col], row[pos.col + 1] = row[pos.col + 1], row[pos.col]
  end

  table_info.alignments[pos.col], table_info.alignments[pos.col + 1] =
    table_info.alignments[pos.col + 1], table_info.alignments[pos.col]

  return helpers.format_reparse_and_move(table_info, pos.row, pos.col - 1)
end

---Move column right (swap with column to the right)
---@return boolean success True if column was moved
function M.move_column_right()
  local helpers = require("markdown-plus.table.helpers")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if pos.col >= table_info.cols - 1 then
    vim.notify("Cannot move column right - already at rightmost position", vim.log.levels.WARN)
    return false
  end

  for _, row in ipairs(table_info.cells) do
    row[pos.col + 1], row[pos.col + 2] = row[pos.col + 2], row[pos.col + 1]
  end

  table_info.alignments[pos.col + 1], table_info.alignments[pos.col + 2] =
    table_info.alignments[pos.col + 2], table_info.alignments[pos.col + 1]

  return helpers.format_reparse_and_move(table_info, pos.row, pos.col + 1)
end

return M
