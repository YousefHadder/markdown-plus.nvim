-- List marker sequence utilities for markdown-plus.nvim
-- Marker arithmetic: computing next/previous markers for ordered, letter, and unordered lists.
local utils = require("markdown-plus.utils")
local M = {}

---Convert index to single letter (1->a, 26->z, 27->a)
---@param idx number Index (1-based)
---@param is_upper boolean Whether to use uppercase
---@return string Single letter
function M.index_to_letter(idx, is_upper)
  local base = is_upper and string.byte("A") or string.byte("a")
  -- Wrap around after 26 letters
  local letter_idx = ((idx - 1) % 26)
  return string.char(base + letter_idx)
end

---Get next letter in sequence (a->b, z->a)
---@param letter string Current letter (single character)
---@param is_upper boolean Whether to use uppercase
---@return string Next letter in sequence
function M.next_letter(letter, is_upper)
  local byte = string.byte(letter)
  local base = is_upper and string.byte("A") or string.byte("a")
  local max = is_upper and string.byte("Z") or string.byte("z")

  if byte < max then
    return string.char(byte + 1)
  else
    -- Wrap around: z->a, Z->A
    return string.char(base)
  end
end

---Get the next marker for a list item, incrementing numbers or letters as appropriate
---For ordered lists: "1." -> "2.", for letters: "a." -> "b."
---For unordered lists: returns same marker ("-", "+", "*")
---@param list_info markdown-plus.ListInfo Table containing list item information
---@return string next_marker The next marker string for the list item (e.g., "2.", "b)", "-")
function M.get_next_marker(list_info)
  local delimiter = list_info.marker:match("[%.%)]$") or ""
  if list_info.type == "ordered" or list_info.type == "ordered_paren" then
    local current_num = tonumber(list_info.marker:match("(%d+)"))
    return (current_num + 1) .. delimiter
  elseif list_info.type == "letter_lower" or list_info.type == "letter_lower_paren" then
    local current_letter = list_info.marker:match("([a-z])")
    return M.next_letter(current_letter, false) .. delimiter
  elseif list_info.type == "letter_upper" or list_info.type == "letter_upper_paren" then
    local current_letter = list_info.marker:match("([A-Z])")
    return M.next_letter(current_letter, true) .. delimiter
  else
    return list_info.marker
  end
end

---Get the previous/initial marker for inserting before current item
---Checks if there's a previous list item at same indent and returns incremented marker,
---otherwise returns initial marker ("1.", "a.", etc.)
---@param list_info markdown-plus.ListInfo Current list information
---@param row number Current row number (1-indexed)
---@return string previous_marker The marker to use for item inserted above (e.g., "1.", "a)", "-")
function M.get_previous_marker(list_info, row)
  -- Lazy require to avoid a circular dependency with the parser module
  local parser = require("markdown-plus.list.parser")
  local is_ordered = list_info.type == "ordered" or list_info.type == "ordered_paren"
  local is_letter_lower = list_info.type == "letter_lower" or list_info.type == "letter_lower_paren"
  local is_letter_upper = list_info.type == "letter_upper" or list_info.type == "letter_upper_paren"
  local delimiter = list_info.marker:match("[%.%)]$")

  if is_ordered or is_letter_lower or is_letter_upper then
    -- Check for previous list item at same indent
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = parser.parse_list_line(prev_line, row - 1)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        if is_ordered then
          local prev_num = tonumber(prev_list_info.marker:match("(%d+)"))
          return (prev_num + 1) .. delimiter
        elseif is_letter_lower then
          local prev_letter = prev_list_info.marker:match("([a-z])")
          return M.next_letter(prev_letter, false) .. delimiter
        else
          local prev_letter = prev_list_info.marker:match("([A-Z])")
          return M.next_letter(prev_letter, true) .. delimiter
        end
      end
    end
    -- No previous item found - return initial marker
    if is_ordered then
      return "1" .. delimiter
    elseif is_letter_lower then
      return "a" .. delimiter
    else
      return "A" .. delimiter
    end
  else
    -- Keep same bullet for unordered lists
    return list_info.marker
  end
end

return M
