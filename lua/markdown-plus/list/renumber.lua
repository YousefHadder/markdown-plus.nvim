-- List renumbering module for markdown-plus.nvim
local shared = require("markdown-plus.list.shared")
local group_scanner = require("markdown-plus.list.group_scanner")
local M = {}

local ORDERED_LIST_CANDIDATE_PATTERNS = {
  "^%s*%d+[%.%)]",
  "^%s*[A-Za-z][%.%)]",
}

-- Re-export group_scanner functions for backwards compatibility
M.set_html_awareness = group_scanner.set_html_awareness
M.is_list_breaking_line = group_scanner.is_list_breaking_line
M.find_list_groups = group_scanner.find_list_groups

---Renumber items in a list group
---@param group table List group
---@return table|nil Changes or nil
function M.renumber_list_group(group)
  if #group.items == 0 then
    return nil
  end

  local changes = {}

  for idx, item in ipairs(group.items) do
    local checkbox_part = ""
    if item.checkbox then
      checkbox_part = " [" .. item.checkbox .. "]"
    end

    -- Determine expected marker based on list type
    local expected_marker = shared.get_marker_for_index(group.list_type, idx)
    local full_marker = expected_marker .. checkbox_part

    local expected_line = item.indent .. full_marker .. shared.spaces_after_marker(full_marker) .. item.content

    -- Only create change if line is different
    if expected_line ~= item.original_line then
      table.insert(changes, {
        line_num = item.line_num,
        new_line = expected_line,
        -- Column where content starts, before and after the rewrite. Used to keep
        -- the cursor on its content character when the marker/spacing length changes.
        old_content_start = #item.original_line - #item.content,
        new_content_start = #item.indent + #full_marker + #shared.spaces_after_marker(full_marker),
      })
    end
  end

  return #changes > 0 and changes or nil
end

---Cheap pre-filter to skip expensive parsing when no ordered list candidates exist
---@param lines string[]
---@return boolean
local function has_ordered_list_candidates(lines)
  for _, line in ipairs(lines) do
    for _, pattern in ipairs(ORDERED_LIST_CANDIDATE_PATTERNS) do
      if line:match(pattern) then
        return true
      end
    end
  end
  return false
end

---Apply line changes using contiguous batch writes
---@param changes {line_num: integer, new_line: string}[]
local function apply_changes(changes)
  table.sort(changes, function(a, b)
    return a.line_num < b.line_num
  end)

  local start_line = nil
  local end_line = nil
  local replacement_lines = {}

  local function flush_segment()
    if not start_line then
      return
    end
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, replacement_lines)
  end

  for _, change in ipairs(changes) do
    if not start_line then
      start_line = change.line_num
      end_line = change.line_num
      replacement_lines = { change.new_line }
    elseif change.line_num == end_line + 1 then
      end_line = change.line_num
      table.insert(replacement_lines, change.new_line)
    else
      flush_segment()
      start_line = change.line_num
      end_line = change.line_num
      replacement_lines = { change.new_line }
    end
  end

  flush_segment()
end

---Renumber all ordered lists in the buffer
function M.renumber_ordered_lists()
  if not vim.bo.modifiable then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if not has_ordered_list_candidates(lines) then
    return
  end

  local modified = false
  local changes = {}

  -- Find all distinct list groups
  local list_groups = M.find_list_groups(lines)

  -- Renumber each list group
  for _, group in ipairs(list_groups) do
    local renumbered = M.renumber_list_group(group)
    if renumbered then
      modified = true
      for _, change in ipairs(renumbered) do
        table.insert(changes, change)
      end
    end
  end

  -- Apply changes if any were made
  if modified then
    -- Capture the cursor first so we can keep it on the same content character
    -- when the rewrite changes the marker/spacing length on the cursor's line.
    -- Without this the cursor keeps its absolute column and drifts as text shifts.
    local cursor_ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    local cursor_change
    if cursor_ok then
      for _, change in ipairs(changes) do
        if change.line_num == cursor[1] then
          cursor_change = change
          break
        end
      end
    end

    apply_changes(changes)

    if cursor_change then
      local col = cursor[2]
      local new_col
      if col >= cursor_change.old_content_start then
        -- Cursor is within the content: shift it by the prefix-length delta.
        new_col = col + (cursor_change.new_content_start - cursor_change.old_content_start)
      else
        -- Cursor is within the marker/indent prefix: leave it, but never let it
        -- spill past where the content now starts.
        new_col = math.min(col, cursor_change.new_content_start)
      end
      new_col = math.max(0, math.min(new_col, #cursor_change.new_line))
      pcall(vim.api.nvim_win_set_cursor, 0, { cursor[1], new_col })
    end
  end
end

---Debug function to show detected list groups
function M.debug_list_groups()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local groups = M.find_list_groups(lines)

  print("=== Detected List Groups ===")
  for i, group in ipairs(groups) do
    print(string.format("Group %d (indent: %d, start: %d):", i, group.indent, group.start_line))
    for _, item in ipairs(group.items) do
      print(string.format("  Line %d: %s", item.line_num, item.original_line))
    end
    print()
  end
end

return M
