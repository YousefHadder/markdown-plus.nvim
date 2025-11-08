---@module 'markdown-plus.table.manipulation'
---@brief [[
--- Table manipulation for markdown tables
---
--- Provides operations to modify table structure:
--- - Insert/delete rows
--- - Insert/delete columns
--- - Duplicate rows/columns
--- - Automatic reformatting after operations
---@brief ]]

local M = {}

---Insert a row in the table
---@param above boolean If true, insert above current row; otherwise below
---@return boolean success True if row was inserted
function M.insert_row(above)
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Create empty row
  local empty_cells = {}
  for i = 1, table_info.cols do
    table.insert(empty_cells, "")
  end

  -- Determine insertion position in cells array
  local insert_index
  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    -- In header or separator - always insert as first data row
    insert_index = 2 -- cells[2] = first data row
  else
    -- In data row - use row mapper for safe conversion
    local current_cells_index = row_mapper.pos_row_to_cells_index(pos.row)
    if not current_cells_index then
      vim.notify("Cannot determine insertion position (internal error)", vim.log.levels.ERROR)
      return false
    end

    if above then
      insert_index = current_cells_index
    else
      insert_index = current_cells_index + 1
    end
  end

  -- Insert the row into cells array
  table.insert(table_info.cells, insert_index, empty_cells)

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to new row (first cell)
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(table_info, insert_index, 0)

  return true
end

---Delete the current row
---@return boolean success True if row was deleted
function M.delete_row()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Cannot delete header or separator
  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    vim.notify("Cannot delete header or separator row", vim.log.levels.WARN)
    return false
  end

  -- Must have at least one data row (cells[1]=header, cells[2]=first data row)
  if #table_info.cells < 2 then
    vim.notify("Cannot delete the only data row", vim.log.levels.WARN)
    return false
  end

  -- Convert position row to cells array index
  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    vim.notify("Cannot delete separator row (internal error)", vim.log.levels.ERROR)
    return false
  end

  -- Validate index is within bounds
  local valid, err = row_mapper.validate_cells_index(cells_index, #table_info.cells)
  if not valid then
    vim.notify("Invalid row index: " .. err, vim.log.levels.ERROR)
    return false
  end

  table.remove(table_info.cells, cells_index)

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Position cursor on the row that moved up (or previous row if last)
  local new_row = pos.row
  if new_row > #table_info.cells then
    new_row = #table_info.cells
  end
  navigation.move_to_cell(table_info, new_row, pos.col)

  return true
end

---Duplicate the current row
---@return boolean success True if row was duplicated
function M.duplicate_row()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Cannot duplicate separator row
  if row_mapper.is_separator_row(pos.row) then
    vim.notify("Cannot duplicate separator row", vim.log.levels.WARN)
    return false
  end

  -- Convert position row to cells array index
  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    vim.notify("Invalid row position (internal error)", vim.log.levels.ERROR)
    return false
  end

  -- Validate and get current cells
  local valid, err = row_mapper.validate_cells_index(cells_index, #table_info.cells)
  if not valid then
    vim.notify("Invalid row index: " .. err, vim.log.levels.ERROR)
    return false
  end

  local current_cells = table_info.cells[cells_index]

  -- Duplicate the cells
  local duplicate_cells = {}
  for _, cell in ipairs(current_cells) do
    table.insert(duplicate_cells, cell)
  end

  -- Insert below current row
  table.insert(table_info.cells, cells_index + 1, duplicate_cells)

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to duplicated row (first cell)
  navigation.move_to_cell(table_info, pos.row + 1, 0)

  return true
end

---Insert a column in the table
---@param left boolean If true, insert left of current column; otherwise right
---@return boolean success True if column was inserted
function M.insert_column(left)
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Determine insertion position
  local insert_col = left and pos.col or pos.col + 1

  -- Insert empty cell in each row
  for _, row in ipairs(table_info.cells) do
    table.insert(row, insert_col + 1, "")
  end

  -- Update column count and add default alignment
  table_info.cols = table_info.cols + 1
  table.insert(table_info.alignments, insert_col + 1, "left")

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to new column (first row of that column)
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(table_info, pos.row, insert_col)

  return true
end

---Delete the current column
---@return boolean success True if column was deleted
function M.delete_column()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Must have at least 2 columns
  if table_info.cols <= 1 then
    vim.notify("Cannot delete the only column", vim.log.levels.WARN)
    return false
  end

  -- Remove column from each row
  for _, row in ipairs(table_info.cells) do
    table.remove(row, pos.col + 1)
  end

  -- Update column count and remove alignment
  table_info.cols = table_info.cols - 1
  table.remove(table_info.alignments, pos.col + 1)

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Position cursor on the column to the left (or same position if first column deleted)
  local navigation = require("markdown-plus.table.navigation")
  local new_col = pos.col
  if new_col >= table_info.cols then
    new_col = table_info.cols - 1
  end
  navigation.move_to_cell(table_info, pos.row, new_col)

  return true
end

---Duplicate the current column
---@return boolean success True if column was duplicated
function M.duplicate_column()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Duplicate column in each row
  for _, row in ipairs(table_info.cells) do
    local cell_content = row[pos.col + 1] or ""
    table.insert(row, pos.col + 2, cell_content)
  end

  -- Update column count and duplicate alignment
  table_info.cols = table_info.cols + 1
  local alignment = table_info.alignments[pos.col + 1] or "left"
  table.insert(table_info.alignments, pos.col + 2, alignment)

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info with correct line numbers
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to duplicated column (first cell)
  local navigation = require("markdown-plus.table.navigation")
  navigation.move_to_cell(table_info, pos.row, pos.col + 1)

  return true
end

---Toggle alignment of the current column
---Cycles through: left → center → right → left
---@return boolean success True if alignment was toggled
function M.toggle_cell_alignment()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Get current alignment (1-indexed in alignments array)
  local col_index = pos.col + 1
  local current_alignment = table_info.alignments[col_index] or "left"

  -- Cycle to next alignment
  local next_alignment
  if current_alignment == "left" then
    next_alignment = "center"
  elseif current_alignment == "center" then
    next_alignment = "right"
  else
    next_alignment = "left"
  end

  -- Update alignment
  table_info.alignments[col_index] = next_alignment

  -- Reformat and update buffer
  formatter.format_table(table_info)

  vim.notify(string.format("Column alignment: %s", next_alignment), vim.log.levels.INFO)
  return true
end

---Move current row up (swap with row above)
---@return boolean success True if row was moved
function M.move_row_up()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Cannot move header or separator
  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    vim.notify("Cannot move header or separator row", vim.log.levels.WARN)
    return false
  end

  -- Convert to cells index
  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  -- Check if we can move up (must be at least second data row, cells[3])
  if cells_index <= 2 then
    vim.notify("Cannot move row up - already at top", vim.log.levels.WARN)
    return false
  end

  -- Swap with row above
  table_info.cells[cells_index], table_info.cells[cells_index - 1] =
    table_info.cells[cells_index - 1], table_info.cells[cells_index]

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to the new position (one row up)
  navigation.move_to_cell(table_info, pos.row - 1, pos.col)

  return true
end

---Move current row down (swap with row below)
---@return boolean success True if row was moved
function M.move_row_down()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Cannot move header or separator
  if row_mapper.is_header_row(pos.row) or row_mapper.is_separator_row(pos.row) then
    vim.notify("Cannot move header or separator row", vim.log.levels.WARN)
    return false
  end

  -- Convert to cells index
  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  -- Check if we can move down
  if cells_index >= #table_info.cells then
    vim.notify("Cannot move row down - already at bottom", vim.log.levels.WARN)
    return false
  end

  -- Swap with row below
  table_info.cells[cells_index], table_info.cells[cells_index + 1] =
    table_info.cells[cells_index + 1], table_info.cells[cells_index]

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to the new position (one row down)
  navigation.move_to_cell(table_info, pos.row + 1, pos.col)

  return true
end

---Clear content of the current cell
---@return boolean success True if cell was cleared
function M.clear_cell()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Cannot clear separator row
  local row_mapper = require("markdown-plus.table.row_mapper")
  if row_mapper.is_separator_row(pos.row) then
    vim.notify("Cannot clear separator row", vim.log.levels.WARN)
    return false
  end

  -- Convert to cells index (header is at cells[1], data rows start at cells[2])
  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  -- Clear the cell
  table_info.cells[cells_index][pos.col + 1] = ""

  -- Reformat and update buffer
  formatter.format_table(table_info)

  return true
end

---Move column left (swap with column to the left)
---@return boolean success True if column was moved
function M.move_column_left()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Check if we can move left
  if pos.col == 0 then
    vim.notify("Cannot move column left - already at leftmost position", vim.log.levels.WARN)
    return false
  end

  -- Swap columns in each row
  for _, row in ipairs(table_info.cells) do
    row[pos.col], row[pos.col + 1] = row[pos.col + 1], row[pos.col]
  end

  -- Swap alignments
  table_info.alignments[pos.col], table_info.alignments[pos.col + 1] =
    table_info.alignments[pos.col + 1], table_info.alignments[pos.col]

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to the new position (one column left)
  navigation.move_to_cell(table_info, pos.row, pos.col - 1)

  return true
end

---Move column right (swap with column to the right)
---@return boolean success True if column was moved
function M.move_column_right()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local navigation = require("markdown-plus.table.navigation")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Check if we can move right
  if pos.col >= table_info.cols - 1 then
    vim.notify("Cannot move column right - already at rightmost position", vim.log.levels.WARN)
    return false
  end

  -- Swap columns in each row
  for _, row in ipairs(table_info.cells) do
    row[pos.col + 1], row[pos.col + 2] = row[pos.col + 2], row[pos.col + 1]
  end

  -- Swap alignments
  table_info.alignments[pos.col + 1], table_info.alignments[pos.col + 2] =
    table_info.alignments[pos.col + 2], table_info.alignments[pos.col + 1]

  -- Reformat and update buffer
  formatter.format_table(table_info)

  -- Re-parse to get updated table info
  table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Move cursor to the new position (one column right)
  navigation.move_to_cell(table_info, pos.row, pos.col + 1)

  return true
end

return M
