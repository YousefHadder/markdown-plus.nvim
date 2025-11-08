---@module 'markdown-plus.table.calculator'
---@brief [[
--- Table calculation and transformation operations
---
--- Provides advanced table operations:
--- - Transpose (swap rows and columns)
--- - Sort by column (numeric and alphabetic)
---@brief ]]

local M = {}

---Get the table configuration
---@return table config
local function get_config()
  local table_module = require("markdown-plus.table")
  return table_module.config or { confirm_destructive = true }
end

---Transpose table (swap rows and columns)
---First row becomes first column, etc.
---@return boolean success True if table was transposed
function M.transpose_table()
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local utils = require("markdown-plus.utils")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  -- Confirm before destructive operation
  local config = get_config()
  if config.confirm_destructive then
    local confirmed = utils.confirm("Transpose table? This will swap rows and columns.", true)
    if not confirmed then
      vim.notify("Transpose cancelled", vim.log.levels.INFO)
      return false
    end
  end

  -- Extract dimensions
  local num_rows = #table_info.cells
  local num_cols = table_info.cols

  -- Create transposed cells (cols become rows)
  local transposed_cells = {}
  for col = 1, num_cols do
    local new_row = {}
    for row = 1, num_rows do
      table.insert(new_row, table_info.cells[row][col] or "")
    end
    table.insert(transposed_cells, new_row)
  end

  -- Update table info
  table_info.cells = transposed_cells
  table_info.cols = num_rows

  -- Reset alignments to default (left)
  table_info.alignments = {}
  for i = 1, num_rows do
    table.insert(table_info.alignments, "left")
  end

  -- Reformat and update buffer
  formatter.format_table(table_info)

  vim.notify("Table transposed successfully", vim.log.levels.INFO)
  return true
end

---Check if a string is numeric
---@param str string String to check
---@return boolean
local function is_numeric(str)
  if str == "" then
    return false
  end
  return tonumber(str) ~= nil
end

---Determine if a column contains primarily numeric values
---@param table_info table Table information
---@param col_index number Column index (1-based)
---@return boolean
local function is_numeric_column(table_info, col_index)
  local numeric_count = 0
  local total_count = 0

  -- Skip header row, check data rows only (cells[2+])
  for i = 2, #table_info.cells do
    local cell = table_info.cells[i][col_index] or ""
    if cell ~= "" then
      total_count = total_count + 1
      if is_numeric(cell) then
        numeric_count = numeric_count + 1
      end
    end
  end

  -- Consider numeric if >50% of non-empty cells are numeric
  return total_count > 0 and (numeric_count / total_count) > 0.5
end

---Compare two cell values
---@param a string First value
---@param b string Second value
---@param ascending boolean Sort ascending if true
---@param numeric boolean Use numeric comparison if true
---@return boolean
local function compare_cells(a, b, ascending, numeric)
  -- Handle empty cells (always sort to bottom regardless of direction)
  local a_empty = a == ""
  local b_empty = b == ""

  if a_empty and b_empty then
    return false -- Both empty, consider equal
  end
  if a_empty then
    return not ascending -- Empty goes to bottom: false for asc, true for desc
  end
  if b_empty then
    return ascending -- Empty goes to bottom: true for asc, false for desc
  end

  -- Both non-empty, do actual comparison
  if numeric then
    local num_a = tonumber(a) or 0
    local num_b = tonumber(b) or 0
    if ascending then
      return num_a < num_b
    else
      return num_a > num_b
    end
  else
    if ascending then
      return a < b
    else
      return a > b
    end
  end
end

---Sort table rows by the current column
---@param ascending boolean Sort ascending if true, descending if false
---@return boolean success True if table was sorted
function M.sort_by_column(ascending)
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local utils = require("markdown-plus.utils")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    vim.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    return false
  end

  -- Must have at least one data row to sort
  if #table_info.cells < 2 then
    vim.notify("No data rows to sort", vim.log.levels.WARN)
    return false
  end

  -- Confirm before destructive operation
  local config = get_config()
  if config.confirm_destructive then
    local direction = ascending and "ascending" or "descending"
    local confirmed = utils.confirm(string.format("Sort table by column %d (%s)?", pos.col + 1, direction), true)
    if not confirmed then
      vim.notify("Sort cancelled", vim.log.levels.INFO)
      return false
    end
  end

  -- Determine if column is numeric
  local col_index = pos.col + 1
  local numeric = is_numeric_column(table_info, col_index)

  -- Extract data rows (skip header at cells[1])
  local data_rows = {}
  for i = 2, #table_info.cells do
    table.insert(data_rows, table_info.cells[i])
  end

  -- Sort data rows by the selected column
  table.sort(data_rows, function(row_a, row_b)
    local cell_a = row_a[col_index] or ""
    local cell_b = row_b[col_index] or ""
    return compare_cells(cell_a, cell_b, ascending, numeric)
  end)

  -- Rebuild cells array with header + sorted data
  local sorted_cells = { table_info.cells[1] } -- Keep header
  for _, row in ipairs(data_rows) do
    table.insert(sorted_cells, row)
  end
  table_info.cells = sorted_cells

  -- Reformat and update buffer
  formatter.format_table(table_info)

  local direction = ascending and "ascending" or "descending"
  local sort_type = numeric and "numeric" or "alphabetic"
  vim.notify(string.format("Table sorted %s (%s)", direction, sort_type), vim.log.levels.INFO)
  return true
end

return M
