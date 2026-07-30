---Insert-mode simulation helpers for specs.
---
---Handlers that yield to `keymap_fallback` queue keys via `nvim_feedkeys` instead of
---editing the buffer directly, so their effect is only observable once the typeahead is
---flushed from a real insert-mode session. These helpers drive that session and capture
---buffer state *before* insert mode exits, so cursor assertions stay meaningful (leaving
---insert mode shifts the cursor one column left).
local M = {}

---@class markdown-plus.spec.InsertResult
---@field lines string[] Buffer lines captured while still in insert mode
---@field cursor integer[] `{ row, col }` captured while still in insert mode

---@type markdown-plus.spec.InsertResult|nil
local captured

---Capture the current buffer state; invoked from a `<Cmd>` mapping mid-insert.
---@return nil
function M.__capture()
  captured = {
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursor = vim.api.nvim_win_get_cursor(0),
  }
end

---Compute the keys needed to enter insert mode with the cursor at `col`.
---@param line string Line contents
---@param col integer 0-indexed byte column for the insert cursor
---@return string enter_key Key that enters insert mode ("i" or "a")
---@return integer normal_col 0-indexed byte column to place the normal-mode cursor on
local function insert_entry(line, col)
  if #line > 0 and col >= #line then
    -- Past the last byte: sit on the final character and append after it
    local last_char_idx = vim.fn.charidx(line, #line - 1)
    return "a", vim.fn.byteidx(line, last_char_idx)
  end
  return "i", col
end

---Press `keys` in insert mode with the cursor at (row, col) and return the resulting state.
---@param keys string Keys to press once insert mode is entered (e.g. "<BS>")
---@param row integer 1-indexed row for the insert cursor
---@param col integer 0-indexed byte column for the insert cursor
---@return markdown-plus.spec.InsertResult
function M.press(keys, row, col)
  -- Backspace behavior across line starts and the insert-start boundary depends on
  -- 'backspace'. Pin it so specs do not inherit whatever the ambient config happens to set.
  vim.o.backspace = "indent,eol,start"

  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local enter_key, normal_col = insert_entry(line, col)

  vim.api.nvim_win_set_cursor(0, { row, normal_col })

  captured = nil
  local sequence = enter_key .. keys .. '<Cmd>lua require("spec.helpers.insert_mode").__capture()<CR><Esc>'
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "x", false)

  return captured
    or {
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
      cursor = vim.api.nvim_win_get_cursor(0),
    }
end

---Install a buffer-local `<BS>` default the way `keymap_helper` does in production:
---the buffer-local mapping targets a `<Plug>` rhs, which `keymap_fallback` recognizes as
---ours and skips when resolving a fallback.
---@param handler fun() Handler invoked by the `<Plug>` mapping
---@param bufnr? integer Buffer to map in (defaults to the current buffer)
---@return nil
function M.map_backspace_default(handler, bufnr)
  vim.keymap.set("i", "<Plug>(MarkdownPlusListBackspace)", handler, { silent = true })
  vim.keymap.set("i", "<BS>", "<Plug>(MarkdownPlusListBackspace)", { buffer = bufnr or 0 })
end

---Remove the mappings installed by `map_backspace_default`.
---The `<Plug>` mapping is global and overwrites the real one registered by
---`list/keymaps.lua` (which wraps the handler in `skip_in_codeblock`), so leaving it behind
---would leak into every later spec in the same Neovim instance.
---@param bufnr? integer Buffer the default was mapped in (defaults to the current buffer)
---@return nil
function M.unmap_backspace_default(bufnr)
  pcall(vim.keymap.del, "i", "<BS>", { buffer = bufnr or 0 })
  pcall(vim.keymap.del, "i", "<Plug>(MarkdownPlusListBackspace)")
end

---Press `<BS>` in insert mode with the cursor at (row, col).
---@param row integer 1-indexed row for the insert cursor
---@param col integer 0-indexed byte column for the insert cursor
---@return markdown-plus.spec.InsertResult
function M.backspace(row, col)
  return M.press("<BS>", row, col)
end

return M
