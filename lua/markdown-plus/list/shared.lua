-- Shared utilities for list handling modules
local parser = require("markdown-plus.list.parser")
local M = {}

-- Constants for list types that support renumbering
M.ORDERABLE_LIST_TYPES = {
  "ordered",
  "letter_lower",
  "letter_upper",
  "ordered_paren",
  "letter_lower_paren",
  "letter_upper_paren",
}

-- Constants for delimiters
M.DELIMITER_DOT = "."
M.DELIMITER_PAREN = ")"

-- Maximum number of lines to look back when searching for parent list item
M.MAX_PARENT_LOOKBACK = 20

---Check if a list type is orderable (supports renumbering)
---@param list_type string List type to check
---@return boolean True if the list type is orderable
function M.is_orderable_type(list_type)
  for _, otype in ipairs(M.ORDERABLE_LIST_TYPES) do
    if list_type == otype then
      return true
    end
  end
  return false
end

---Extract content from a list line after the marker
---@param line string The line to extract from
---@param list_info table List information
---@return string Content after the marker
function M.extract_list_content(line, list_info)
  local marker_end = #list_info.indent + #list_info.full_marker
  return line:sub(marker_end + 1):match("^%s*(.*)") or ""
end

---Calculate the column position where list content starts (after marker and checkbox)
---Note: full_marker already includes checkbox if present (e.g., "- [x]", "1. [ ]")
---@param list_info table List information
---@return number The column position where content starts
function M.get_content_start_col(list_info)
  return #list_info.indent + #list_info.full_marker + 1
end

---Get the expected marker for a given index and list type
---@param list_type string Type of list (ordered, letter_lower, etc.)
---@param index number 1-based index in the list
---@return string The marker (e.g., "1.", "a)", etc.)
function M.get_marker_for_index(list_type, index)
  if list_type == "ordered" then
    return index .. M.DELIMITER_DOT
  elseif list_type == "ordered_paren" then
    return index .. M.DELIMITER_PAREN
  elseif list_type == "letter_lower" then
    return parser.index_to_letter(index, false) .. M.DELIMITER_DOT
  elseif list_type == "letter_lower_paren" then
    return parser.index_to_letter(index, false) .. M.DELIMITER_PAREN
  elseif list_type == "letter_upper" then
    return parser.index_to_letter(index, true) .. M.DELIMITER_DOT
  elseif list_type == "letter_upper_paren" then
    return parser.index_to_letter(index, true) .. M.DELIMITER_PAREN
  end
  return ""
end

---Find parent list item by looking upward from current line
---Checks if a line is a continuation line of a list item by looking for a parent
---@param line string The line to check
---@param line_num number The line number (1-indexed)
---@param lines string[] All buffer lines
---@return table|nil, number|nil List info and row number of parent, or nil if not found
function M.find_parent_list_item(line, line_num, lines)
  -- Must be indented
  local indent = line:match("^(%s*)")
  if not indent or #indent == 0 then
    return nil
  end

  -- Must not be a list item itself
  if parser.parse_list_line(line, line_num) then
    return nil
  end

  -- Look upward for a list item with matching content position
  for i = line_num - 1, math.max(1, line_num - M.MAX_PARENT_LOOKBACK), -1 do
    local prev_line = lines[i]
    if not prev_line then
      break
    end

    -- Try to parse as list item
    local list_info = parser.parse_list_line(prev_line, i)
    if list_info then
      -- Calculate where content starts in the list item
      local content_start_col = M.get_content_start_col(list_info)

      -- Check if current line's indentation matches list content position
      if #indent == content_start_col then
        return list_info, i
      end
    end

    -- Stop if we hit a line with less indentation (different block)
    local prev_indent = prev_line:match("^(%s*)")
    if prev_indent and #prev_indent < #indent then
      break
    end
  end

  return nil
end

---Check if a line is a continuation line of a list item
---A continuation line has indentation that matches a list item's content position
---@param line string The line to check
---@param line_num number The line number (1-indexed)
---@param lines string[] All buffer lines
---@return boolean True if the line is a continuation line
function M.is_continuation_line(line, line_num, lines)
  return M.find_parent_list_item(line, line_num, lines) ~= nil
end

return M
