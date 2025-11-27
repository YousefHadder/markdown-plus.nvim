-- List parsing module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local M = {}

-- Constants
local DELIMITER_DOT = "."
local DELIMITER_PAREN = ")"

---List patterns for detection
---@class markdown-plus.list.Patterns
---@field unordered string Pattern for unordered lists (-, +, *)
---@field ordered string Pattern for ordered lists (1., 2., etc.)
---@field checkbox string Pattern for checkbox lists (- [ ], - [x], etc.)
---@field ordered_checkbox string Pattern for ordered checkbox lists (1. [ ], etc.)
---@field letter_lower string Pattern for lowercase letter lists (a., b., c.)
---@field letter_upper string Pattern for uppercase letter lists (A., B., C.)
---@field letter_lower_checkbox string Pattern for lowercase letter checkbox lists (a. [ ])
---@field letter_upper_checkbox string Pattern for uppercase letter checkbox lists (A. [ ])
---@field ordered_paren string Pattern for parenthesized ordered lists (1), 2), etc.)
---@field letter_lower_paren string Pattern for parenthesized lowercase letter lists (a), b), c.)
---@field letter_upper_paren string Pattern for parenthesized uppercase letter lists (A), B), C.)
---@field ordered_paren_checkbox string Pattern for parenthesized ordered checkbox lists (1) [ ])
---@field letter_lower_paren_checkbox string Pattern for parenthesized lowercase letter checkbox lists (a) [ ])
---@field letter_upper_paren_checkbox string Pattern for parenthesized uppercase letter checkbox lists (A) [ ])
---@field unordered_empty string Pattern for empty unordered lists at EOL (-, +, *)
---@field ordered_empty string Pattern for empty ordered lists at EOL (1., 2., etc.)
---@field letter_lower_empty string Pattern for empty lowercase letter lists at EOL (a., b., c.)
---@field letter_upper_empty string Pattern for empty uppercase letter lists at EOL (A., B., C.)
---@field ordered_paren_empty string Pattern for empty parenthesized ordered lists at EOL (1), 2), etc.)
---@field letter_lower_paren_empty string Pattern for empty parenthesized lowercase letter lists at EOL (a), b), c.)
---@field letter_upper_paren_empty string Pattern for empty parenthesized uppercase letter lists at EOL (A), B), C.)

---@type markdown-plus.list.Patterns
M.patterns = {
  unordered = "^(%s*)([%-%+%*])%s+",
  ordered = "^(%s*)(%d+)%.%s+",
  checkbox = "^(%s*)([%-%+%*])%s+%[(.?)%]%s+",
  ordered_checkbox = "^(%s*)(%d+)%.%s+%[(.?)%]%s+",
  letter_lower = "^(%s*)([a-z])%.%s+",
  letter_upper = "^(%s*)([A-Z])%.%s+",
  letter_lower_checkbox = "^(%s*)([a-z])%.%s+%[(.?)%]%s+",
  letter_upper_checkbox = "^(%s*)([A-Z])%.%s+%[(.?)%]%s+",
  ordered_paren = "^(%s*)(%d+)%)%s+",
  letter_lower_paren = "^(%s*)([a-z])%)%s+",
  letter_upper_paren = "^(%s*)([A-Z])%)%s+",
  ordered_paren_checkbox = "^(%s*)(%d+)%)%s+%[(.?)%]%s+",
  letter_lower_paren_checkbox = "^(%s*)([a-z])%)%s+%[(.?)%]%s+",
  letter_upper_paren_checkbox = "^(%s*)([A-Z])%)%s+%[(.?)%]%s+",
  -- Empty item patterns (marker at end of line, no trailing space required)
  -- These handle the case where trim_trailing_whitespace removes the space
  unordered_empty = "^(%s*)([%-%+%*])$",
  ordered_empty = "^(%s*)(%d+)%.$",
  letter_lower_empty = "^(%s*)([a-z])%.$",
  letter_upper_empty = "^(%s*)([A-Z])%.$",
  ordered_paren_empty = "^(%s*)(%d+)%)$",
  letter_lower_paren_empty = "^(%s*)([a-z])%)$",
  letter_upper_paren_empty = "^(%s*)([A-Z])%)$",
}

-- Pattern configuration: defines order and metadata for pattern matching
local PATTERN_CONFIG = {
  { pattern = "ordered_checkbox", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_lower_checkbox", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_upper_checkbox", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "checkbox", type = "unordered", delimiter = "", has_checkbox = true },
  { pattern = "ordered_paren_checkbox", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = true },
  {
    pattern = "letter_lower_paren_checkbox",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  {
    pattern = "letter_upper_paren_checkbox",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  { pattern = "ordered", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_lower", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_upper", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "ordered_paren", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_lower_paren", type = "letter_lower_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_upper_paren", type = "letter_upper_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "unordered", type = "unordered", delimiter = "", has_checkbox = false },
  -- Empty item patterns (marker at EOL without trailing space)
  -- These are checked last to prefer matching with content when possible
  { pattern = "ordered_empty", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_lower_empty", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_upper_empty", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "ordered_paren_empty", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  {
    pattern = "letter_lower_paren_empty",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
  },
  {
    pattern = "letter_upper_paren_empty",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
  },
  { pattern = "unordered_empty", type = "unordered", delimiter = "", has_checkbox = false },
}

---Build list info object from parsed components
---@param indent string Indentation whitespace
---@param marker string List marker (without delimiter)
---@param checkbox string|nil Checkbox state
---@param config table Pattern config
---@return table List info
local function build_list_info(indent, marker, checkbox, config)
  local full_marker = marker .. config.delimiter
  if config.has_checkbox then
    full_marker = full_marker .. " [" .. checkbox .. "]"
  end

  return {
    type = config.type,
    indent = indent,
    marker = marker .. config.delimiter,
    checkbox = config.has_checkbox and checkbox or nil,
    full_marker = full_marker,
  }
end

---Parse a line to detect list information
---@param line string Line to parse
---@return markdown-plus.ListInfo|nil List info or nil if not a list
function M.parse_list_line(line)
  if not line then
    return nil
  end

  -- Try each pattern in order (checkbox variants first, then regular)
  for _, config in ipairs(PATTERN_CONFIG) do
    local pattern = M.patterns[config.pattern]
    if config.has_checkbox then
      local indent, marker, checkbox = line:match(pattern)
      if indent and marker and checkbox then
        return build_list_info(indent, marker, checkbox, config)
      end
    else
      local indent, marker = line:match(pattern)
      if indent and marker then
        return build_list_info(indent, marker, nil, config)
      end
    end
  end

  return nil
end

---Check if a list item is empty (only contains marker)
---@param line string Line to check
---@param list_info table List information
---@return boolean
function M.is_empty_list_item(line, list_info)
  if not line or not list_info then
    return false
  end

  local content_pattern = "^" .. utils.escape_pattern(list_info.indent .. list_info.full_marker) .. "%s*$"
  return line:match(content_pattern) ~= nil
end

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
  if list_info.type == "ordered" then
    local current_num = tonumber(list_info.marker:match("(%d+)"))
    return (current_num + 1) .. DELIMITER_DOT
  elseif list_info.type == "ordered_paren" then
    local current_num = tonumber(list_info.marker:match("(%d+)"))
    return (current_num + 1) .. DELIMITER_PAREN
  elseif list_info.type == "letter_lower" then
    local current_letter = list_info.marker:match("([a-z])")
    return M.next_letter(current_letter, false) .. DELIMITER_DOT
  elseif list_info.type == "letter_lower_paren" then
    local current_letter = list_info.marker:match("([a-z])")
    return M.next_letter(current_letter, false) .. DELIMITER_PAREN
  elseif list_info.type == "letter_upper" then
    local current_letter = list_info.marker:match("([A-Z])")
    return M.next_letter(current_letter, true) .. DELIMITER_DOT
  elseif list_info.type == "letter_upper_paren" then
    local current_letter = list_info.marker:match("([A-Z])")
    return M.next_letter(current_letter, true) .. DELIMITER_PAREN
  else
    -- Keep same bullet for unordered lists
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
  local is_ordered = list_info.type == "ordered" or list_info.type == "ordered_paren"
  local is_letter_lower = list_info.type == "letter_lower" or list_info.type == "letter_lower_paren"
  local is_letter_upper = list_info.type == "letter_upper" or list_info.type == "letter_upper_paren"
  local delimiter = list_info.marker:match("[%.%)]$")

  if is_ordered then
    -- Check for previous list item at same indent
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_num = tonumber(prev_list_info.marker:match("(%d+)"))
        return (prev_num + 1) .. delimiter
      end
    end
    return "1" .. delimiter
  elseif is_letter_lower then
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_letter = prev_list_info.marker:match("([a-z])")
        return M.next_letter(prev_letter, false) .. delimiter
      end
    end
    return "a" .. delimiter
  elseif is_letter_upper then
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_letter = prev_list_info.marker:match("([A-Z])")
        return M.next_letter(prev_letter, true) .. delimiter
      end
    end
    return "A" .. delimiter
  else
    -- Keep same bullet for unordered lists
    return list_info.marker
  end
end

return M
