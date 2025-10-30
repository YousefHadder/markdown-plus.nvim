-- List renumbering module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local M = {}

-- Constants
local DELIMITER_DOT = "."
local DELIMITER_PAREN = ")"

---Extract content from a list line after the marker
---@param line string The line to extract from
---@param list_info table List information
---@return string Content after the marker
local function extract_list_content(line, list_info)
  local marker_end = #list_info.indent + #list_info.full_marker
  return line:sub(marker_end + 1):match("^%s*(.*)") or ""
end

---Check if a line breaks list continuity
---@param line string
---@return boolean
function M.is_list_breaking_line(line)
  -- Empty lines terminate list groups
  if not line or line:match("^%s*$") then
    return true
  end

  -- Any non-list content breaks list continuity
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

    if
      list_info
      and (
        list_info.type == "ordered"
        or list_info.type == "letter_lower"
        or list_info.type == "letter_upper"
        or list_info.type == "ordered_paren"
        or list_info.type == "letter_lower_paren"
        or list_info.type == "letter_upper_paren"
      )
    then
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
      local content = extract_list_content(line, list_info)

      table.insert(current_group.items, {
        line_num = i,
        indent = list_info.indent,
        checkbox = list_info.checkbox,
        content = content,
        original_line = line,
      })
    else
      -- Not an ordered/letter list item
      if M.is_list_breaking_line(line) then
        -- Clear all active groups
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
    local expected_marker
    if group.list_type == "ordered" then
      expected_marker = idx .. DELIMITER_DOT
    elseif group.list_type == "ordered_paren" then
      expected_marker = idx .. DELIMITER_PAREN
    elseif group.list_type == "letter_lower" then
      expected_marker = parser.index_to_letter(idx, false) .. DELIMITER_DOT
    elseif group.list_type == "letter_lower_paren" then
      expected_marker = parser.index_to_letter(idx, false) .. DELIMITER_PAREN
    elseif group.list_type == "letter_upper" then
      expected_marker = parser.index_to_letter(idx, true) .. DELIMITER_DOT
    elseif group.list_type == "letter_upper_paren" then
      expected_marker = parser.index_to_letter(idx, true) .. DELIMITER_PAREN
    end

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
