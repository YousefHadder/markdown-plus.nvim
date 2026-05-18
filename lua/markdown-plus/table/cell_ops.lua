---@module 'markdown-plus.table.cell_ops'
---@brief [[
--- Cell operations for markdown tables
---
--- Provides in-place cell content and alignment modifications:
--- - clear_cell: Clear the content of the current cell
--- - toggle_cell_alignment: Cycle column alignment (left → center → right)
--- - insert_break: Insert the configured wrap_break token at cursor inside a cell
--- - wrap_cell: Re-flow the current cell content to a maximum width using <br>
--- - unwrap_cell: Strip every <br> variant from the current cell
---@brief ]]

local M = {}
local utils = require("markdown-plus.utils")

---Resolve the wrap_break token from the active table config.
---@return string
local function get_wrap_break()
  local ok, table_module = pcall(require, "markdown-plus.table")
  if ok and table_module.config and type(table_module.config.wrap_break) == "string" then
    return table_module.config.wrap_break
  end
  return "<br>"
end

---Resolve the default max_column_width from the active table config (or nil).
---@return integer|nil
local function get_default_width()
  local ok, table_module = pcall(require, "markdown-plus.table")
  if ok and table_module.config then
    return table_module.config.max_column_width
  end
  return nil
end

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

---Insert the configured wrap_break token at the cursor position inside a table cell.
---This is a pure text edit; it does NOT reformat the table.
---@return boolean success True if the break was inserted
function M.insert_break()
  local parser = require("markdown-plus.table.parser")
  local row_mapper = require("markdown-plus.table.row_mapper")

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    utils.notify("Not in a table", vim.log.levels.WARN)
    return false
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot insert break in separator row", vim.log.levels.WARN)
    return false
  end

  local wrap_break = get_wrap_break()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""

  local new_line = line:sub(1, col) .. wrap_break .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { row, col + #wrap_break })
  return true
end

---Re-flow the content of the current cell to a maximum width, inserting
---wrap_break at word boundaries. Existing breaks in the cell are flattened
---first so the result is idempotent (re-running with the same width is a no-op).
---
---Width resolution order: explicit `width` argument → config.max_column_width
---→ interactive prompt.
---@param width? integer Target width in display cells (must be >= 1)
---@return boolean success True if the cell was wrapped
function M.wrap_cell(width)
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")
  local cell_breaks = require("markdown-plus.table.cell_breaks")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot wrap separator row", vim.log.levels.WARN)
    return false
  end

  if width == nil then
    width = get_default_width()
  end
  if width == nil then
    local input = vim.fn.input("Wrap width: ")
    if input == "" then
      return false
    end
    width = tonumber(input)
  end
  if type(width) ~= "number" or width < 1 or width ~= math.floor(width) then
    utils.notify("Wrap width must be a positive integer", vim.log.levels.ERROR)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  local cell = table_info.cells[cells_index][pos.col + 1] or ""
  table_info.cells[cells_index][pos.col + 1] = cell_breaks.wrap_text(cell, width, get_wrap_break())

  local formatter = require("markdown-plus.table.format")
  formatter.format_table(table_info)
  return true
end

---Strip every <br> variant from the current cell, collapsing the content to a
---single line. Whitespace runs are collapsed to single spaces and trimmed.
---@return boolean success True if the cell was unwrapped
function M.unwrap_cell()
  local helpers = require("markdown-plus.table.helpers")
  local row_mapper = require("markdown-plus.table.row_mapper")
  local cell_breaks = require("markdown-plus.table.cell_breaks")

  local table_info, pos = helpers.get_table_and_pos()
  if not table_info or not pos then
    return false
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot unwrap separator row", vim.log.levels.WARN)
    return false
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    return false
  end

  local cell = table_info.cells[cells_index][pos.col + 1] or ""
  table_info.cells[cells_index][pos.col + 1] = cell_breaks.unwrap(cell)

  local formatter = require("markdown-plus.table.format")
  formatter.format_table(table_info)
  return true
end

return M
