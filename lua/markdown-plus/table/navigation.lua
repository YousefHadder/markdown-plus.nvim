---@module 'markdown-plus.table.navigation'
---@brief [[
--- Table navigation utilities for markdown tables
---
--- Provides cursor positioning within table cells for manipulation operations
---@brief ]]

local M = {}

-- Separator row is always at index 1 (between header at 0 and data rows at 2+)
local SEPARATOR_ROW = 1

---Find the next unescaped pipe at or after `from`
---
---Delegates to the parser so cell boundaries are resolved by exactly the rule that produced
---`table_info.cells`; a local copy would drift and land the cursor in a different cell.
---@param line string Table row
---@param from integer 1-indexed position to start searching from
---@return integer? col Column of the pipe (1-indexed), or nil when the row has none left
local function next_unescaped_pipe(line, from)
  return require("markdown-plus.table.parser").next_unescaped_pipe(line, from)
end

---Resolve the first typing position inside the cell opened by the pipe at `open_col`.
---
---A non-empty cell lands on its first content character. An all-whitespace cell has no content to
---land on, so it lands one padding space in — where content sits in a formatted table — instead of
---running past the cell and stopping on the closing pipe. The search is bounded by the closing
---pipe for exactly that reason.
---
---Column alignment is deliberately ignored: a centre- or right-aligned empty cell still lands at
---the left-most typing position, because that is where the user expects to start typing.
---@param line string Table row
---@param open_col integer Column of the pipe opening the cell, or 0 for a row with no leading pipe
---@return integer col Column position (1-indexed)
local function cell_start_after(line, open_col)
  -- An unterminated row (no closing pipe) runs to the end of the line.
  local close_col = next_unescaped_pipe(line, open_col + 1) or (#line + 1)

  for col = open_col + 1, close_col - 1 do
    if not line:sub(col, col):match("%s") then
      return col
    end
  end

  -- Empty cell: one padding space in, clamped so a zero-width cell (`||`) stays inside itself.
  return math.min(open_col + 2, close_col)
end

---Find the start column of a cell in a row
---@param line string Table row
---@param cell_index integer Cell index (0-based)
---@return integer? col Column position (1-indexed) or nil
local function find_cell_start_col(line, cell_index)
  local leading_pipe = next_unescaped_pipe(line, 1)
  local open_col

  -- Locate the leading pipe's real column rather than assuming column 1, so indented tables
  -- (inside a list item, say) resolve their first cell instead of landing on the pipe itself.
  -- A row may also omit the leading pipe (`a | b`), in which case the first cell opens at the
  -- start of the line.
  if leading_pipe and vim.trim(line):match("^|") then
    open_col = leading_pipe
  else
    open_col = 0
  end

  for _ = 1, cell_index do
    open_col = next_unescaped_pipe(line, open_col + 1)
    if not open_col then
      return nil
    end
  end

  return cell_start_after(line, open_col)
end

---Move cursor to a specific cell in the table
---@param table_info TableInfo Parsed table information
---@param row integer Row index (0 = header, 1 = separator, 2+ = data)
---@param col integer Column index (0-based)
---@return boolean success True if cursor was moved
function M.move_to_cell(table_info, row, col)
  -- Validate column bounds
  if col < 0 or col >= table_info.cols then
    return false
  end

  -- Validate row bounds
  -- row: 0=header (cells[1]), 1=separator (virtual), 2+=data rows (cells[2+])
  -- For data rows (row >= 2), check if corresponding cells index exists
  if row < 0 or row > #table_info.cells then
    return false
  end

  -- Calculate actual line number (account for separator between header and data rows)
  -- row: 0=header, 1=separator, 2+=data rows
  local line_num
  if row == 0 then
    line_num = table_info.start_row
  elseif row == SEPARATOR_ROW then
    line_num = table_info.start_row + 1
  else
    -- row >= 2: data rows
    line_num = table_info.start_row + row
  end

  -- Get the line
  local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
  if not line then
    return false
  end

  -- Find cell start column
  local cell_col = find_cell_start_col(line, col)
  if not cell_col then
    return false
  end

  -- Move cursor
  vim.fn.cursor(line_num, cell_col)
  return true
end

---Move to a cell in the specified direction
---@param row_delta integer Row offset (-1 for up, 1 for down, 0 for horizontal)
---@param col_delta integer Column offset (-1 for left, 1 for right, 0 for vertical)
---@return boolean success True if moved successfully
local function move_in_direction(row_delta, col_delta)
  local parser = require("markdown-plus.table.parser")

  -- Get cursor position in table (this also validates we're in a table)
  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Get table info (we need to call this separately as get_cursor_position_in_table
  -- doesn't return the full table_info)
  local table_info = parser.get_table_at_cursor()
  if not table_info then
    return false
  end

  -- Calculate new position
  local new_row = pos.row + row_delta
  local new_col = pos.col + col_delta

  -- Handle horizontal wrapping (columns wrap around in same row)
  if col_delta ~= 0 then
    if new_col < 0 then
      new_col = table_info.cols - 1 -- Wrap to last column
    elseif new_col >= table_info.cols then
      new_col = 0 -- Wrap to first column
    end
  end

  -- Handle vertical wrapping (rows wrap around in same column)
  if row_delta ~= 0 then
    -- Calculate max row: cells array length corresponds to max valid row index
    -- Row 0 = header (cells[1]), Row 2+ = data rows (cells[2+])
    -- Max data row index is: #cells (since cells[#cells] is the last data row)
    local max_row = #table_info.cells

    -- Skip separator row - always jump over it
    if new_row == SEPARATOR_ROW then
      new_row = row_delta > 0 and 2 or 0 -- Moving down: first data row, up: header
    elseif new_row < 0 then
      new_row = max_row -- Wrap to last data row
    elseif new_row > max_row then
      new_row = 0 -- Wrap to header
    end
  end

  return M.move_to_cell(table_info, new_row, new_col)
end

---Move to the cell to the left of current position
---@return boolean success True if moved successfully
function M.move_left()
  return move_in_direction(0, -1)
end

---Move to the cell to the right of current position
---@return boolean success True if moved successfully
function M.move_right()
  return move_in_direction(0, 1)
end

---Move to the cell above current position
---@return boolean success True if moved successfully
function M.move_up()
  return move_in_direction(-1, 0)
end

---Move to the cell below current position
---@return boolean success True if moved successfully
function M.move_down()
  return move_in_direction(1, 0)
end

return M
