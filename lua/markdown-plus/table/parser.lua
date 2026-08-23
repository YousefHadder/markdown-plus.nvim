---@module 'markdown-plus.table.parser'
---@brief [[
--- Table parser for markdown tables
---
--- Parses markdown table structure including:
--- - Row and column detection
--- - Cell content extraction
--- - Alignment detection from separator row
--- - Support for both standard and GFM tables
---@brief ]]

local M = {}

---@class TableInfo
---@field start_row integer First line of table (1-indexed)
---@field end_row integer Last line of table (1-indexed)
---@field rows string[] Table rows as strings
---@field header string Header row
---@field separator string Separator row
---@field data_rows string[] Data rows
---@field cols integer Number of columns
---@field alignments string[] Column alignments ('left', 'center', 'right')
---@field cells string[][] Parsed cell contents [row][col]

---Report whether the pipe at `col` is a real cell boundary rather than an escaped literal.
---
---A backslash escapes the character after it, so a backslash run of odd length leaves the pipe
---escaped, while an even-length run escapes itself and leaves the pipe as a boundary. This is the
---rule `split_row_into_cells` applies while scanning; it lives here so every caller that needs to
---locate boundaries agrees with the cells the parser actually produced.
---@param line string Table row
---@param col integer 1-indexed column of the pipe
---@return boolean is_boundary
function M.is_cell_boundary(line, col)
  local backslashes = 0
  local i = col - 1
  while i >= 1 and line:sub(i, i) == "\\" do
    backslashes = backslashes + 1
    i = i - 1
  end
  return backslashes % 2 == 0
end

---Find the next unescaped pipe at or after `from`
---@param line string Table row
---@param from integer 1-indexed position to start searching from
---@return integer? col Column of the pipe (1-indexed), or nil when the row has none left
function M.next_unescaped_pipe(line, from)
  for col = from, #line do
    if line:sub(col, col) == "|" and M.is_cell_boundary(line, col) then
      return col
    end
  end
  return nil
end

---Parse alignment from separator cell
---@param sep_cell string Separator cell (e.g., "---", ":---:", "---:")
---@return string alignment 'left', 'center', or 'right'
local function parse_alignment(sep_cell)
  local trimmed = vim.trim(sep_cell)
  local starts_colon = trimmed:match("^:")
  local ends_colon = trimmed:match(":$")

  if starts_colon and ends_colon then
    return "center"
  elseif ends_colon then
    return "right"
  else
    return "left"
  end
end

---Split table row into cells
---@param row string Table row
---@return string[] cells Array of cell contents
local function split_row_into_cells(row)
  local cells = {}
  local trimmed = vim.trim(row)

  -- Remove leading and trailing pipes
  if trimmed:match("^|") then
    trimmed = trimmed:sub(2)
  end
  if trimmed:match("|$") then
    trimmed = trimmed:sub(1, -2)
  end

  -- Split by pipe, handling escaped pipes
  local current = ""
  local escaped = false
  local i = 1
  while i <= #trimmed do
    local char = trimmed:sub(i, i)
    if escaped then
      -- Previous char was backslash, current char is escaped
      if char == "|" then
        current = current .. "|"
      else
        current = current .. "\\" .. char
      end
      escaped = false
    elseif char == "\\" then
      -- Mark next character as escaped
      escaped = true
    elseif char == "|" then
      -- Unescaped pipe, end of cell
      table.insert(cells, vim.trim(current))
      current = ""
    else
      current = current .. char
    end
    i = i + 1
  end

  -- Add last cell
  if current ~= "" or #cells > 0 then
    table.insert(cells, vim.trim(current))
  end

  return cells
end

---Check if a line is a table separator
---@param line string Line to check
---@return boolean
local function is_separator_row(line)
  local trimmed = vim.trim(line)
  -- Must start and end with pipes, contain only |, :, -, and whitespace
  return trimmed:match("^|?[%s:|-]+|?$") ~= nil and trimmed:match("[-]") ~= nil
end

---Check if a line is a table row
---@param line string Line to check
---@return boolean
local function is_table_row(line)
  local trimmed = vim.trim(line)
  -- Must contain at least one pipe
  return trimmed:match("|") ~= nil
end

---Get table at cursor position
---@return TableInfo? table_info Table information or nil if not in table
function M.get_table_at_cursor()
  local cursor_row = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Check if current line is part of a table
  if not is_table_row(lines[cursor_row]) then
    return nil
  end

  -- Find table start
  local start_row = cursor_row
  while start_row > 1 and is_table_row(lines[start_row - 1]) do
    start_row = start_row - 1
  end

  -- Find table end
  local end_row = cursor_row
  while end_row < #lines and is_table_row(lines[end_row + 1]) do
    end_row = end_row + 1
  end

  -- Extract table rows
  local table_rows = {}
  for i = start_row, end_row do
    table.insert(table_rows, lines[i])
  end

  -- Must have at least 2 rows (header + separator)
  if #table_rows < 2 then
    return nil
  end

  -- Second row should be separator
  if not is_separator_row(table_rows[2]) then
    return nil
  end

  local header = table_rows[1]
  local separator = table_rows[2]
  local data_rows = {}
  for i = 3, #table_rows do
    table.insert(data_rows, table_rows[i])
  end

  -- Parse header to get column count
  local header_cells = split_row_into_cells(header)
  local cols = #header_cells

  -- Parse alignments from separator
  local sep_cells = split_row_into_cells(separator)
  local alignments = {}
  for i = 1, cols do
    if sep_cells[i] then
      table.insert(alignments, parse_alignment(sep_cells[i]))
    else
      table.insert(alignments, "left")
    end
  end

  -- Parse all cells
  local cells = {}
  table.insert(cells, header_cells)
  for _, row in ipairs(data_rows) do
    local row_cells = split_row_into_cells(row)
    -- Pad row to match column count
    while #row_cells < cols do
      table.insert(row_cells, "")
    end
    table.insert(cells, row_cells)
  end

  return {
    start_row = start_row,
    end_row = end_row,
    rows = table_rows,
    header = header,
    separator = separator,
    data_rows = data_rows,
    cols = cols,
    alignments = alignments,
    cells = cells,
  }
end

---Get current cursor position within table
---@return {row: integer, col: integer}? position Row (0=header, 1=separator, 2+=data rows) and column (0-indexed), or nil
function M.get_cursor_position_in_table()
  local table_info = M.get_table_at_cursor()
  if not table_info then
    return nil
  end

  local cursor_row = vim.fn.line(".")
  local cursor_col = vim.fn.col(".")

  -- Calculate row position (0 = header, 1 = separator, 2+ = data rows)
  local table_row = cursor_row - table_info.start_row

  -- Calculate column position by counting pipes before cursor
  local line = vim.api.nvim_get_current_line()
  local pipe_count = 0
  for i = 1, cursor_col - 1 do
    if line:sub(i, i) == "|" and M.is_cell_boundary(line, i) then
      pipe_count = pipe_count + 1
    end
  end

  -- Adjust for leading pipe
  local col
  if vim.trim(line):match("^|") then
    col = pipe_count - 1
  else
    col = pipe_count
  end

  return {
    row = table_row,
    col = math.max(0, math.min(col, table_info.cols - 1)),
  }
end

return M
