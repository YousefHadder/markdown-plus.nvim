-- Footnotes list window module for markdown-plus.nvim
-- Provides a picker UI to view and navigate all footnotes
local parser = require("markdown-plus.footnotes.parser")
local utils = require("markdown-plus.utils")

local M = {}

---Format a footnote for display in picker
---@param fn markdown-plus.footnotes.Footnote
---@return string formatted_line
local function format_footnote_line(fn)
  local icon
  local content

  -- Determine status icon
  if not fn.definition then
    icon = "✗" -- Missing definition
  elseif #fn.references == 0 then
    icon = "⚠" -- Orphan (unused)
  else
    icon = " " -- Normal
  end

  -- Get content preview
  if fn.definition then
    content = fn.definition.content
    if #content > 50 then
      content = content:sub(1, 47) .. "..."
    end
  else
    content = "(no definition)"
  end

  local ref_count = #fn.references
  local ref_info = ref_count == 1 and "1 ref" or (ref_count .. " refs")

  return string.format("%s [^%s] %s (%s)", icon, fn.id, content, ref_info)
end

---Open the footnotes list picker
---@param layout? string Unused, kept for API compatibility
function M.open_footnotes_window(layout)
  -- layout parameter is ignored, we always use vim.ui.select
  local _ = layout

  local bufnr = vim.api.nvim_get_current_buf()

  -- Get all footnotes
  local footnotes = parser.get_all_footnotes(bufnr)

  if #footnotes == 0 then
    utils.notify("No footnotes in document", vim.log.levels.INFO)
    return
  end

  -- Build picker items
  local items = {}
  for _, fn in ipairs(footnotes) do
    table.insert(items, {
      footnote = fn,
      display = format_footnote_line(fn),
    })
  end

  vim.ui.select(items, {
    prompt = "Footnotes (" .. #footnotes .. "):",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then
      return
    end

    local fn = choice.footnote

    -- Jump to definition if it exists, otherwise first reference
    if fn.definition then
      vim.api.nvim_win_set_cursor(0, { fn.definition.line_num, 0 })
      vim.cmd("normal! zz")
    elseif #fn.references > 0 then
      local ref = fn.references[1]
      vim.api.nvim_win_set_cursor(0, { ref.line_num, ref.start_col - 1 })
      vim.cmd("normal! zz")
    end
  end)
end

---Toggle the footnotes window (for API compatibility, just opens picker)
function M.toggle_footnotes_window()
  M.open_footnotes_window()
end

---Close the footnotes window (no-op for picker, kept for API compatibility)
function M.close_footnotes_window()
  -- No-op: vim.ui.select handles its own lifecycle
end

return M
