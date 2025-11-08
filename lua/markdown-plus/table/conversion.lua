---@module 'markdown-plus.table.conversion'
---@brief [[
--- Table format conversion operations
---
--- Provides conversion between table formats:
--- - Markdown table to CSV
--- - CSV to Markdown table
---@brief ]]

local M = {}

---Escape a CSV field if it contains special characters
---@param field string Field content
---@return string Escaped field (quoted if necessary)
local function escape_csv_field(field)
  -- Empty fields don't need quotes
  if field == "" then
    return ""
  end

  -- Check if field needs quoting (contains comma, quote, or newline)
  if field:match('[,"\n]') then
    -- Escape quotes by doubling them
    local escaped = field:gsub('"', '""')
    return '"' .. escaped .. '"'
  end

  return field
end

---Parse a CSV line handling quoted fields
---@param line string CSV line
---@return string[] cells Array of cell contents
local function parse_csv_line(line)
  local cells = {}
  local current_cell = ""
  local in_quotes = false
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)

    if in_quotes then
      if char == '"' then
        -- Check if it's an escaped quote (doubled)
        if i < #line and line:sub(i + 1, i + 1) == '"' then
          current_cell = current_cell .. '"'
          i = i + 1 -- Skip next quote
        else
          -- End of quoted field
          in_quotes = false
        end
      else
        current_cell = current_cell .. char
      end
    else
      if char == '"' then
        -- Start of quoted field
        in_quotes = true
      elseif char == "," then
        -- Field separator
        table.insert(cells, current_cell)
        current_cell = ""
      else
        current_cell = current_cell .. char
      end
    end

    i = i + 1
  end

  -- Add last cell
  table.insert(cells, current_cell)

  return cells
end

---Convert table to CSV format
---Replaces the table with CSV lines
---@return boolean success True if conversion succeeded
function M.table_to_csv()
  local parser = require("markdown-plus.table.parser")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  -- Build CSV lines
  local csv_lines = {}
  for _, row in ipairs(table_info.cells) do
    local escaped_cells = {}
    for _, cell in ipairs(row) do
      table.insert(escaped_cells, escape_csv_field(cell))
    end
    table.insert(csv_lines, table.concat(escaped_cells, ","))
  end

  -- Replace table with CSV
  vim.api.nvim_buf_set_lines(0, table_info.start_row - 1, table_info.end_row, false, csv_lines)

  vim.notify(string.format("Converted table to CSV (%d rows)", #csv_lines), vim.log.levels.INFO)
  return true
end

---Convert CSV to markdown table
---Converts CSV lines under cursor to a formatted table
---Check if a line looks like CSV data (contains at least one comma)
---@param line string Line to check
---@return boolean
local function is_csv_line(line)
  if not line or line == "" or line:match("^%s*$") then
    return false
  end
  -- Must contain at least one comma and not be markdown formatting
  -- Exclude common markdown patterns that might contain commas
  if line:match("^%s*#") then -- Headers
    return false
  end
  if line:match("^%s*[-*+]%s") then -- List items
    return false
  end
  if line:match("^%s*>") then -- Blockquotes
    return false
  end
  if line:match("^%s*```") then -- Code fences
    return false
  end
  if line:match("^%s*|") then -- Already a table
    return false
  end
  -- Must have at least one comma
  return line:find(",") ~= nil
end

---@return boolean success True if conversion succeeded
function M.csv_to_table()
  local formatter = require("markdown-plus.table.format")
  local utils = require("markdown-plus.utils")

  -- Get current line
  local cursor = utils.get_cursor()
  local current_line = cursor[1]

  -- Ensure current line is CSV
  local curr_line_text = vim.api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  if not is_csv_line(curr_line_text) then
    vim.notify("Cursor is not on a CSV line", vim.log.levels.WARN)
    return false
  end

  -- Find CSV block (consecutive CSV lines)
  local start_row = current_line
  local end_row = current_line

  -- Find start of CSV block (move up while lines are CSV)
  while start_row > 1 do
    local line = vim.api.nvim_buf_get_lines(0, start_row - 2, start_row - 1, false)[1]
    if not is_csv_line(line) then
      break
    end
    start_row = start_row - 1
  end

  -- Find end of CSV block (move down while lines are CSV)
  local total_lines = vim.api.nvim_buf_line_count(0)
  while end_row < total_lines do
    local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
    if not line or not is_csv_line(line) then
      break
    end
    end_row = end_row + 1
  end

  -- end_row now points to first line after CSV block (or total_lines)
  -- nvim_buf_get_lines uses exclusive end, so this is perfect for the range

  -- Get CSV lines
  local csv_lines = vim.api.nvim_buf_get_lines(0, start_row - 1, math.min(end_row, total_lines), false)
  if #csv_lines == 0 then
    vim.notify("No CSV data found", vim.log.levels.WARN)
    return false
  end

  -- Parse CSV lines
  local cells = {}
  local max_cols = 0
  for _, line in ipairs(csv_lines) do
    local row_cells = parse_csv_line(line)
    table.insert(cells, row_cells)
    max_cols = math.max(max_cols, #row_cells)
  end

  -- Ensure all rows have same number of columns
  for _, row in ipairs(cells) do
    while #row < max_cols do
      table.insert(row, "")
    end
  end

  -- Build table info structure
  local table_info = {
    start_row = start_row,
    end_row = end_row,
    cells = cells,
    cols = max_cols,
    alignments = {},
  }

  -- Default alignments (all left)
  for i = 1, max_cols do
    table.insert(table_info.alignments, "left")
  end

  -- Format and update buffer
  formatter.format_table(table_info)

  vim.notify(string.format("Converted CSV to table (%d rows, %d columns)", #cells, max_cols), vim.log.levels.INFO)
  return true
end

return M
