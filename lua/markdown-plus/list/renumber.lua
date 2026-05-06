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

    local expected_line = item.indent .. expected_marker .. checkbox_part .. " " .. item.content

    -- Only create change if line is different
    if expected_line ~= item.original_line then
      table.insert(changes, {
        line_num = item.line_num,
        new_line = expected_line,
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
    apply_changes(changes)
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
