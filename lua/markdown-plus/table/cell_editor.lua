---@module 'markdown-plus.table.cell_editor'
---@brief [[
--- Floating popup editor for a single table cell.
---
--- Pattern inspired by Org-mode's `C-c '`: open the current cell in a scratch
--- buffer with markdown filetype, split on the configured `wrap_break` so each
--- segment is one buffer line, and let the user edit freely with real newlines.
--- On save, join lines back with `wrap_break`, write to the source table, and
--- reformat.
---
--- `M.open()` returns a session table (or nil on failure). Tests drive the
--- session by manipulating `state.scratch_buf` and calling `state.save()` /
--- `state.cancel()` directly. Interactive users hit `<CR>` / `:w` / `q` /
--- `<Esc><Esc>` mapped on the scratch buffer.
---@brief ]]

local M = {}
local utils = require("markdown-plus.utils")

---Resolve the cell_editor sub-config from the active table config.
---@return markdown-plus.InternalTableCellEditorConfig
local function get_editor_config()
  local ok, table_module = pcall(require, "markdown-plus.table")
  if ok and table_module.config and table_module.config.cell_editor then
    return table_module.config.cell_editor
  end
  return { enabled = true, border = "rounded", width = 0.6, height = 0.4 }
end

---Resolve the wrap_break token from the active table config.
---@return string
local function get_wrap_break()
  local ok, table_module = pcall(require, "markdown-plus.table")
  if ok and table_module.config and type(table_module.config.wrap_break) == "string" then
    return table_module.config.wrap_break
  end
  return "<br>"
end

---Compute centered floating-window geometry from fractional dimensions.
---@param config markdown-plus.InternalTableCellEditorConfig
---@return {row: integer, col: integer, width: integer, height: integer}
local function compute_geometry(config)
  local total_cols = vim.o.columns
  local total_lines = vim.o.lines
  local width = math.max(20, math.floor(total_cols * (config.width or 0.6)))
  local height = math.max(5, math.floor(total_lines * (config.height or 0.4)))
  local row = math.max(0, math.floor((total_lines - height) / 2))
  local col = math.max(0, math.floor((total_cols - width) / 2))
  return { row = row, col = col, width = width, height = height }
end

---Open the cell editor popup for the cell under the cursor.
---On success returns a session state table; nil otherwise. The session exposes
---`save()` and `cancel()` callbacks that are also wired to scratch-buffer
---keymaps and the BufWriteCmd autocmd for interactive use.
---@return table|nil state Session state, or nil on failure
function M.open()
  local config = get_editor_config()
  if config.enabled == false then
    utils.notify("Cell editor is disabled", vim.log.levels.WARN)
    return nil
  end

  local parser = require("markdown-plus.table.parser")
  local row_mapper = require("markdown-plus.table.row_mapper")
  local cell_breaks = require("markdown-plus.table.cell_breaks")

  local table_info = parser.get_table_at_cursor()
  if not table_info then
    utils.notify("Not in a table", vim.log.levels.WARN)
    return nil
  end

  local pos = parser.get_cursor_position_in_table()
  if not pos then
    utils.notify("Cannot determine cell position", vim.log.levels.WARN)
    return nil
  end

  if row_mapper.is_separator_row(pos.row) then
    utils.notify("Cannot edit separator row", vim.log.levels.WARN)
    return nil
  end

  local cells_index = row_mapper.pos_row_to_cells_index(pos.row)
  if not cells_index then
    utils.notify("Internal error: invalid cell index", vim.log.levels.ERROR)
    return nil
  end

  local orig_win = vim.api.nvim_get_current_win()
  local orig_buf = vim.api.nvim_get_current_buf()
  local cell_content = table_info.cells[cells_index][pos.col + 1] or ""
  local segments = cell_breaks.split_segments(cell_content)

  -- Create scratch buffer
  local scratch_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch_buf].bufhidden = "wipe"
  vim.bo[scratch_buf].buftype = "acwrite"
  vim.bo[scratch_buf].filetype = "markdown"
  -- Unique name so :w doesn't try to write a real file
  local buf_name = string.format("markdown-plus://cell-editor/%d", scratch_buf)
  pcall(vim.api.nvim_buf_set_name, scratch_buf, buf_name)
  vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, segments)
  vim.bo[scratch_buf].modified = false

  local geom = compute_geometry(config)
  local scratch_win = vim.api.nvim_open_win(scratch_buf, true, {
    relative = "editor",
    width = geom.width,
    height = geom.height,
    row = geom.row,
    col = geom.col,
    border = config.border or "rounded",
    title = string.format(" Cell editor — row %d col %d ", pos.row, pos.col + 1),
    title_pos = "center",
  })

  local state = {
    orig_win = orig_win,
    orig_buf = orig_buf,
    scratch_win = scratch_win,
    scratch_buf = scratch_buf,
    table_info = table_info,
    pos = pos,
    cells_index = cells_index,
    closed = false,
  }

  local function close_scratch()
    if state.closed then
      return
    end
    state.closed = true
    if vim.api.nvim_win_is_valid(scratch_win) then
      pcall(vim.api.nvim_win_close, scratch_win, true)
    end
  end

  ---@return boolean success
  function state.save()
    if state.closed then
      return false
    end
    if not vim.api.nvim_buf_is_valid(scratch_buf) then
      return false
    end
    if not vim.api.nvim_win_is_valid(orig_win) then
      utils.notify("Original window was closed; cannot save cell", vim.log.levels.ERROR)
      close_scratch()
      return false
    end
    if not vim.api.nvim_buf_is_valid(orig_buf) then
      utils.notify("Original buffer was deleted; cannot save cell", vim.log.levels.ERROR)
      close_scratch()
      return false
    end
    if vim.api.nvim_win_get_buf(orig_win) ~= orig_buf then
      utils.notify("Original window now shows a different buffer; cannot save cell", vim.log.levels.ERROR)
      close_scratch()
      return false
    end

    local lines = vim.api.nvim_buf_get_lines(scratch_buf, 0, -1, false)
    local joined = cell_breaks.join_segments(lines, get_wrap_break())

    -- Switch focus to the original window so format_table and parser run there.
    vim.api.nvim_set_current_win(orig_win)
    state.table_info.cells[state.cells_index][state.pos.col + 1] = joined

    local formatter = require("markdown-plus.table.format")
    formatter.format_table(state.table_info)

    -- Place cursor back in the cell that was edited; widths may have shifted.
    local updated = parser.get_table_at_cursor()
    if updated then
      local navigation = require("markdown-plus.table.navigation")
      navigation.move_to_cell(updated, state.pos.row, state.pos.col)
    end

    close_scratch()
    return true
  end

  ---@return boolean success
  function state.cancel()
    close_scratch()
    return true
  end

  -- Keymaps on scratch buffer
  local opts = { buffer = scratch_buf, silent = true, nowait = true }
  vim.keymap.set("n", "<CR>", function()
    state.save()
  end, opts)
  vim.keymap.set("n", "q", function()
    state.cancel()
  end, opts)
  vim.keymap.set("n", "<Esc><Esc>", function()
    state.cancel()
  end, opts)

  -- Intercept :w for save
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = scratch_buf,
    callback = function()
      state.save()
    end,
  })

  -- If the popup closes by other means (e.g. :q), treat as cancel.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(scratch_win),
    callback = function()
      state.closed = true
    end,
    once = true,
  })

  return state
end

return M
