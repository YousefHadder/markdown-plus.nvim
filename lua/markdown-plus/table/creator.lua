---@module 'markdown-plus.table.creator'
---@brief [[
--- Table creator for markdown tables
---
--- Provides interactive table creation with:
--- - Configurable dimensions (rows x columns)
--- - Default alignment support
--- - Automatic formatting
--- - Cursor positioning in first cell
---@brief ]]

local M = {}
local utils = require("markdown-plus.utils")

---Create a new table at cursor position
---@param rows integer Number of data rows (excluding header)
---@param cols integer Number of columns
---@param default_alignment? string Default alignment ('left', 'center', 'right')
function M.create_table(rows, cols, default_alignment)
  default_alignment = default_alignment or "left"

  -- Validate input
  if rows < 1 or cols < 1 then
    utils.notify("Rows and columns must be at least 1", vim.log.levels.ERROR)
    return
  end

  if rows > 100 or cols > 50 then
    utils.notify("Table too large (max 100 rows, 50 columns)", vim.log.levels.ERROR)
    return
  end

  -- Build table structure
  local lines = {}

  -- Header row
  local header_cells = {}
  for i = 1, cols do
    table.insert(header_cells, "Header " .. i)
  end
  table.insert(lines, "| " .. table.concat(header_cells, " | ") .. " |")

  -- Separator row
  local separator_cells = {}
  for i = 1, cols do
    local sep
    if default_alignment == "center" then
      sep = ":---:"
    elseif default_alignment == "right" then
      sep = "---:"
    else
      sep = "---"
    end
    table.insert(separator_cells, sep)
  end
  table.insert(lines, "| " .. table.concat(separator_cells, " | ") .. " |")

  -- Data rows
  for r = 1, rows do
    local row_cells = {}
    for c = 1, cols do
      table.insert(row_cells, "")
    end
    table.insert(lines, "| " .. table.concat(row_cells, " | ") .. " |")
  end

  -- Insert table at cursor position
  local cursor_line = vim.fn.line(".")
  vim.api.nvim_buf_set_lines(0, cursor_line - 1, cursor_line - 1, false, lines)

  -- Format the table
  vim.fn.cursor(cursor_line, 1)
  local parser = require("markdown-plus.table.parser")
  local formatter = require("markdown-plus.table.format")
  local table_info = parser.get_table_at_cursor()
  if table_info then
    formatter.format_table(table_info)

    -- Position cursor in first data cell
    vim.fn.cursor(cursor_line + 2, 3)
  end
end

---Prompt user for table dimensions and create table
function M.create_table_interactive()
  -- Prompt for columns
  local cols_input = vim.fn.input("Number of columns: ")
  local cols = tonumber(cols_input)
  if not cols or cols < 1 then
    utils.notify("Invalid column count", vim.log.levels.ERROR)
    return
  end

  -- Prompt for rows
  local rows_input = vim.fn.input("Number of rows (data rows, excluding header): ")
  local rows = tonumber(rows_input)
  if not rows or rows < 1 then
    utils.notify("Invalid row count", vim.log.levels.ERROR)
    return
  end

  -- Get configuration
  local table_module = require("markdown-plus.table")
  M.create_table(rows, cols, table_module.config.default_alignment)
end

return M
