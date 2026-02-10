-- List renumbering module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local M = {}

---Check if a line breaks list continuity
---@param line string
---@param line_num number|nil The line number (1-indexed). Optional, but must be provided together with `lines` for continuation line checks.
---@param lines string[]|nil All buffer lines. Optional, but must be provided together with `line_num` for continuation line checks.
---@return boolean
function M.is_list_breaking_line(line, line_num, lines)
  -- Empty lines terminate list groups
  if not line or line:match("^%s*$") then
    -- But check if it's a continuation line first
    if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
      return false
    end
    return true
  end

  -- Any non-list content breaks list continuity
  if parser.parse_list_line(line, line_num) then
    return false
  end

  -- Check if it's a continuation line
  if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
    return false
  end

  -- Any non-list content (headers, paragraphs, etc.) breaks list continuity
  return true
end

---Find all distinct list groups in the buffer
---@param lines string[] All buffer lines
---@return table[] List of list groups
function M.find_list_groups(lines)
  local groups = {}
  local current_groups_by_indent = {} -- Track active groups by indentation level

  for i, line in ipairs(lines) do
    local list_info = parser.parse_list_line(line)

    if list_info and shared.is_orderable_type(list_info.type) then
      local indent_level = #list_info.indent
      local list_type = list_info.type

      -- When we encounter a list item at a certain indent level,
      -- clear all groups at DEEPER indents
      for key, _ in pairs(current_groups_by_indent) do
        local group_indent = tonumber(key:match("^(%d+)_"))
        if group_indent and group_indent > indent_level then
          current_groups_by_indent[key] = nil
        end
      end

      -- Check if we have an active group at this indentation level and type
      local group_key = indent_level .. "_" .. list_type
      local current_group = current_groups_by_indent[group_key]

      if not current_group then
        -- Create new group for this indentation level and type
        current_group = {
          indent = indent_level,
          list_type = list_type,
          start_line = i,
          items = {},
        }
        current_groups_by_indent[group_key] = current_group
        table.insert(groups, current_group)
      end

      -- Add item to current group
      local content = shared.extract_list_content(line, list_info)

      table.insert(current_group.items, {
        line_num = i,
        indent = list_info.indent,
        checkbox = list_info.checkbox,
        content = content,
        original_line = line,
      })
    else
      -- Not an ordered/letter list item (could be unordered list or non-list content)
      if list_info then
        -- It's a valid list item but not orderable (e.g., unordered: -, *, +)
        -- Per CommonMark spec: different list marker types are separate lists
        -- An unordered item at indent N breaks orderable groups at indent >= N
        -- But does NOT break parent groups at shallower indents
        local unordered_indent = #list_info.indent
        for key, _ in pairs(current_groups_by_indent) do
          local group_indent = tonumber(key:match("^(%d+)_"))
          if group_indent and group_indent >= unordered_indent then
            current_groups_by_indent[key] = nil
          end
        end
      elseif M.is_list_breaking_line(line, i, lines) then
        -- Non-list content (blank line, paragraph, header, etc.)
        -- This breaks ALL groups at all indent levels
        current_groups_by_indent = {}
      end
    end
  end

  return groups
end

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

---Renumber all ordered lists in the buffer
function M.renumber_ordered_lists()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
    for _, change in ipairs(changes) do
      utils.set_line(change.line_num, change.new_line)
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
