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

---Read the state captured by the most recent `__capture()`, falling back to the buffer's
---current state. For specs that drive their own key-processing burst (one that has to set
---something up *inside* insert mode, which `press()` cannot express) and still want the
---mid-insert snapshot.
---
---Consumes the slot: a burst whose `<Cmd>` capture never ran must fall back to the live buffer,
---not silently hand back the snapshot an earlier test left behind. Call `__reset()` before the
---burst so the fallback is reached for the right reason.
---@return markdown-plus.spec.InsertResult
function M.__captured()
  local result = captured
  captured = nil
  return result
    or {
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
      cursor = vim.api.nvim_win_get_cursor(0),
    }
end

---Discard any captured state, so a stale snapshot cannot leak into the next burst.
---@return nil
function M.__reset()
  captured = nil
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
  -- Each call models a fresh user keypress, so any fallback guard left over from a previous
  -- press must be gone. In a real session the guard expires on the next event-loop turn;
  -- specs drive the typeahead synchronously and never reach one.
  require("markdown-plus.keymap_fallback").reset()

  -- Backspace behavior across line starts and the insert-start boundary depends on
  -- 'backspace'. Pin it so specs do not inherit whatever the ambient config happens to set —
  -- and restore it afterwards, since this is a *global* option and leaking it would silently
  -- change the meaning of every later spec in the same Neovim instance.
  local saved_backspace = vim.o.backspace
  vim.o.backspace = "indent,eol,start"

  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local enter_key, normal_col = insert_entry(line, col)

  vim.api.nvim_win_set_cursor(0, { row, normal_col })

  captured = nil
  local sequence = enter_key .. keys .. '<Cmd>lua require("spec.helpers.insert_mode").__capture()<CR><Esc>'
  -- pcall only so the global option is restored on the way out; the error is rethrown
  -- immediately after, since a burst that blew up is a spec failure worth seeing.
  local ok, err = pcall(vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes(sequence, true, false, true), "x", false)
  vim.o.backspace = saved_backspace
  assert(ok, err)

  return captured
    or {
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
      cursor = vim.api.nvim_win_get_cursor(0),
    }
end

---Press `keys` in *normal* mode with the cursor at (row, col) and return the resulting state.
---
---Used for handlers that yield to `keymap_fallback` from normal mode (`o`, `O`): the fallback
---queues keys instead of editing the buffer, so a real key-processing burst is required. The
---trailing `<Esc>` closes the insert session that `o`/`O` open; state is captured before it.
---
---Shares the module-local `captured` slot with `press()`; both reset it before feeding, so the
---two are safe to interleave across tests but must not be nested within one another. Note that
---effects Vim applies only on leaving insert mode — a count, for instance — are by definition
---absent from the returned mid-insert snapshot; read the buffer after this call for those.
---@param keys string Keys to press (e.g. "o")
---@param row integer 1-indexed row for the cursor
---@param col integer 0-indexed byte column for the cursor
---@return markdown-plus.spec.InsertResult
function M.press_normal(keys, row, col)
  -- Same rationale as `press()`: specs never reach the event-loop turn that expires the guard.
  require("markdown-plus.keymap_fallback").reset()

  vim.api.nvim_win_set_cursor(0, { row, col })

  -- A spec that called a handler directly may have left a *pending* `startinsert` behind: it
  -- takes effect on the next main-loop pass, i.e. in the middle of the burst below, where it
  -- would swallow `keys` as literal text. `stopinsert` cancels the pending flag; a leading
  -- `<Esc>` does not, because the typeahead is consumed before the flag is applied.
  vim.cmd("stopinsert")

  -- Specs that call a fallback handler directly leave the keys it queued sitting in the
  -- typeahead (nothing drains them without a key-processing burst). Flush them first so they
  -- cannot interleave with this press.
  vim.api.nvim_feedkeys("", "x", false)
  vim.cmd("stopinsert")

  captured = nil
  local sequence = keys .. '<Cmd>lua require("spec.helpers.insert_mode").__capture()<CR><Esc>'
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "x", false)

  return captured
    or {
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
      cursor = vim.api.nvim_win_get_cursor(0),
    }
end

---`maparg()` dicts for the global `<Plug>` mappings overwritten by `map_default`, keyed by
---"<mode>\0<plug>". The real ones are registered by `list/keymaps.lua` (which wraps the
---handler in `skip_in_codeblock`), so they are restored rather than deleted on teardown.
local saved_plugs = {}

---Install a buffer-local default the way `keymap_helper` does in production: the
---buffer-local mapping targets a `<Plug>` rhs, which `keymap_fallback` recognizes as ours
---and skips when resolving a fallback.
---@param mode string Mapping mode ("i", "n", ...)
---@param lhs string Default key (e.g. "<CR>")
---@param plug string `<Plug>` name the default forwards to
---@param handler fun() Handler invoked by the `<Plug>` mapping
---@param bufnr? integer Buffer to map in (defaults to the current buffer)
---@return nil
function M.map_default(mode, lhs, plug, handler, bufnr)
  local existing = vim.fn.maparg(plug, mode, false, true)
  saved_plugs[mode .. "\0" .. plug] = type(existing) == "table" and existing.lhs and existing or nil
  vim.keymap.set(mode, plug, handler, { silent = true })
  vim.keymap.set(mode, lhs, plug, { buffer = bufnr or 0 })
end

---Remove the mappings installed by `map_default`, restoring the production `<Plug>` mapping
---when there was one. Leaving our stand-in behind would leak into every later spec in the
---same Neovim instance.
---@param mode string Mapping mode used with `map_default`
---@param lhs string Default key used with `map_default`
---@param plug string `<Plug>` name used with `map_default`
---@param bufnr? integer Buffer the default was mapped in (defaults to the current buffer)
---@return nil
function M.unmap_default(mode, lhs, plug, bufnr)
  pcall(vim.keymap.del, mode, lhs, { buffer = bufnr or 0 })

  local key = mode .. "\0" .. plug
  local saved = saved_plugs[key]
  saved_plugs[key] = nil

  if saved then
    pcall(vim.fn.mapset, saved)
    return
  end
  pcall(vim.keymap.del, mode, plug)
end

---Install the buffer-local `<BS>` default (see `map_default`).
---@param handler fun() Handler invoked by the `<Plug>` mapping
---@param bufnr? integer Buffer to map in (defaults to the current buffer)
---@return nil
function M.map_backspace_default(handler, bufnr)
  M.map_default("i", "<BS>", "<Plug>(MarkdownPlusListBackspace)", handler, bufnr)
end

---Remove the mappings installed by `map_backspace_default`.
---@param bufnr? integer Buffer the default was mapped in (defaults to the current buffer)
---@return nil
function M.unmap_backspace_default(bufnr)
  M.unmap_default("i", "<BS>", "<Plug>(MarkdownPlusListBackspace)", bufnr)
end

---Press `<BS>` in insert mode with the cursor at (row, col).
---@param row integer 1-indexed row for the insert cursor
---@param col integer 0-indexed byte column for the insert cursor
---@return markdown-plus.spec.InsertResult
function M.backspace(row, col)
  return M.press("<BS>", row, col)
end

return M
