-- Footnote navigation module for markdown-plus.nvim
local parser = require("markdown-plus.footnotes.parser")
local utils = require("markdown-plus.utils")

local M = {}

---Jump from a footnote reference to its definition
function M.goto_definition()
  local bufnr = 0
  local fn_info = parser.get_footnote_at_cursor(bufnr)

  if not fn_info then
    utils.notify("No footnote under cursor", vim.log.levels.WARN)
    return
  end

  -- If already on definition, do nothing
  if fn_info.type == "definition" then
    utils.notify("Already at definition for [^" .. fn_info.id .. "]", vim.log.levels.INFO)
    return
  end

  -- Find the definition
  local def = parser.find_definition(bufnr, fn_info.id)
  if not def then
    utils.notify("No definition found for [^" .. fn_info.id .. "]", vim.log.levels.WARN)
    return
  end

  -- Jump to definition, position cursor after ": "
  local line = vim.api.nvim_buf_get_lines(bufnr, def.line_num - 1, def.line_num, false)[1]
  local content_start = line:find(":%s*")
  if content_start then
    content_start = content_start + 1
    -- Skip space after colon if present
    if line:sub(content_start, content_start) == " " then
      content_start = content_start + 1
    end
  else
    content_start = #line + 1
  end

  vim.api.nvim_win_set_cursor(0, { def.line_num, content_start - 1 })
  utils.notify("Jumped to definition of [^" .. fn_info.id .. "]", vim.log.levels.INFO)
end

---Jump from a footnote definition to its reference(s)
---If multiple references exist, shows a selection UI
function M.goto_reference()
  local bufnr = 0
  local fn_info = parser.get_footnote_at_cursor(bufnr)

  if not fn_info then
    utils.notify("No footnote under cursor", vim.log.levels.WARN)
    return
  end

  -- Find all references
  local refs = parser.find_references(bufnr, fn_info.id)

  if #refs == 0 then
    utils.notify("No references found for [^" .. fn_info.id .. "]", vim.log.levels.WARN)
    return
  end

  -- If only one reference, jump directly
  if #refs == 1 then
    local ref = refs[1]
    vim.api.nvim_win_set_cursor(0, { ref.line_num, ref.start_col - 1 })
    utils.notify("Jumped to reference of [^" .. fn_info.id .. "]", vim.log.levels.INFO)
    return
  end

  -- Multiple references - show selection UI
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local items = {}

  for _, ref in ipairs(refs) do
    local line_preview = lines[ref.line_num] or ""
    -- Truncate long lines
    if #line_preview > 60 then
      line_preview = line_preview:sub(1, 57) .. "..."
    end
    table.insert(items, {
      ref = ref,
      display = string.format("Line %d: %s", ref.line_num, line_preview),
    })
  end

  vim.ui.select(items, {
    prompt = "Select reference to [^" .. fn_info.id .. "]:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(0, { choice.ref.line_num, choice.ref.start_col - 1 })
    end
  end)
end

---Jump to the next footnote reference in the document
function M.next_footnote()
  local bufnr = 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line, current_col = cursor[1], cursor[2] + 1 -- 1-indexed

  local all_refs = parser.find_all_references(bufnr)

  if #all_refs == 0 then
    utils.notify("No footnotes in document", vim.log.levels.INFO)
    return
  end

  -- Find the next reference after cursor
  for _, ref in ipairs(all_refs) do
    if ref.line_num > current_line or (ref.line_num == current_line and ref.start_col > current_col) then
      vim.api.nvim_win_set_cursor(0, { ref.line_num, ref.start_col - 1 })
      return
    end
  end

  -- Wrap around to first reference
  local first = all_refs[1]
  vim.api.nvim_win_set_cursor(0, { first.line_num, first.start_col - 1 })
  utils.notify("Wrapped to first footnote", vim.log.levels.INFO)
end

---Jump to the previous footnote reference in the document
function M.prev_footnote()
  local bufnr = 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line, current_col = cursor[1], cursor[2] + 1 -- 1-indexed

  local all_refs = parser.find_all_references(bufnr)

  if #all_refs == 0 then
    utils.notify("No footnotes in document", vim.log.levels.INFO)
    return
  end

  -- Find the previous reference before cursor (iterate in reverse)
  for i = #all_refs, 1, -1 do
    local ref = all_refs[i]
    if ref.line_num < current_line or (ref.line_num == current_line and ref.end_col < current_col) then
      vim.api.nvim_win_set_cursor(0, { ref.line_num, ref.start_col - 1 })
      return
    end
  end

  -- Wrap around to last reference
  local last = all_refs[#all_refs]
  vim.api.nvim_win_set_cursor(0, { last.line_num, last.start_col - 1 })
  utils.notify("Wrapped to last footnote", vim.log.levels.INFO)
end

return M
