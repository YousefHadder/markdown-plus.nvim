-- List parsing module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local ts = require("markdown-plus.treesitter")
local M = {}

-- Constants
local DELIMITER_DOT = "."
local DELIMITER_PAREN = ")"

---Map treesitter marker nodes to list type names
local TS_MARKER_TYPES = {
  [ts.nodes.LIST_MARKER_MINUS] = { type = "unordered", marker = "-", delimiter = "" },
  [ts.nodes.LIST_MARKER_PLUS] = { type = "unordered", marker = "+", delimiter = "" },
  [ts.nodes.LIST_MARKER_STAR] = { type = "unordered", marker = "*", delimiter = "" },
  [ts.nodes.LIST_MARKER_DOT] = { type = "ordered", delimiter = DELIMITER_DOT },
  [ts.nodes.LIST_MARKER_PARENTHESIS] = { type = "ordered_paren", delimiter = DELIMITER_PAREN },
}

-- Map checkbox nodes to checkbox state
local TS_CHECKBOX_TYPES = {
  [ts.nodes.TASK_LIST_MARKER_UNCHECKED] = " ",
  [ts.nodes.TASK_LIST_MARKER_CHECKED] = "x",
}

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
  -- is_empty allows callers to skip these when scanning for group membership
  {
    pattern = "ordered_empty",
    type = "ordered",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_lower_empty",
    type = "letter_lower",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_upper_empty",
    type = "letter_upper",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "ordered_paren_empty",
    type = "ordered_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_lower_paren_empty",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_upper_paren_empty",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  { pattern = "unordered_empty", type = "unordered", delimiter = "", has_checkbox = false, is_empty = true },
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

---Parse list info a specific row (1-indexed)
---@param row number 1-indexed row number
---@return markdown-plus.ListInfo|nil
local function parse_list_line_ts(row)
  local node = ts.get_node_at_position(row, 0, { ignore_injections = true })
  if not node then
    return nil
  end

  -- Find list_item ancestor
  local list_item = ts.find_ancestor(node, ts.nodes.LIST_ITEM)
  if not list_item then
    return nil
  end

  -- Check list_item starts on requested row (not a continuation line)
  local item_start_row = list_item:range() + 1 -- Convert to 1-indexed
  if item_start_row ~= row then
    -- This line is part of a multi-line list item but not the start
    -- Treesitter correctly identified it as belonging to a list_item that started elsewhere
    -- This can happen with 4-space indented nested lists which treesitter sees differently
    return nil
  end

  -- Find marker and checkbox child nodes
  local marker_node, checkbox_node
  for child in list_item:iter_children() do
    local child_type = child:type()
    if TS_MARKER_TYPES[child_type] then
      marker_node = child
    elseif TS_CHECKBOX_TYPES[child_type] then
      checkbox_node = child
    end
  end

  if not marker_node then
    return nil
  end

  -- Extract info from marker node
  local marker_type_info = TS_MARKER_TYPES[marker_node:type()]
  local marker_text = vim.treesitter.get_node_text(marker_node, 0)

  -- Treesitter includes leading whitespace in the marker node, so extract indent from marker text
  local indent = marker_text:match("^(%s*)") or ""
  -- Remove the indent from marker_text for further processing
  marker_text = marker_text:sub(#indent + 1)

  -- Extract marker value
  local marker, list_type, delimiter
  if marker_type_info.type == "ordered" then
    marker = marker_text:match("(%d+)")
    if not marker then
      return nil
    end -- letter list, fall through to regex
    list_type = "ordered"
    delimiter = DELIMITER_DOT
  elseif marker_type_info.type == "ordered_paren" then
    marker = marker_text:match("(%d+)")
    if not marker then
      return nil
    end -- letter list, fall through to regex
    list_type = "ordered_paren"
    delimiter = DELIMITER_PAREN
  else
    -- Unordered: -, +, *
    marker = marker_type_info.marker
    list_type = "unordered"
    delimiter = ""
  end

  -- Handle checkbox — read actual text to preserve case (e.g. "X" vs "x")
  local checkbox_state = nil
  if checkbox_node then
    local checkbox_text = vim.treesitter.get_node_text(checkbox_node, 0)
    checkbox_state = checkbox_text:match("%[(.-)%]") or " "
  end

  return build_list_info(indent, marker, checkbox_state, {
    type = list_type,
    delimiter = delimiter,
    has_checkbox = checkbox_state ~= nil,
  })
end

---@class markdown-plus.list.ParseOpts
---@field skip_empty_patterns? boolean When true, skip empty-marker patterns (marker at EOL without trailing space)

---Parse list info using regex patterns
---Used as fallback when treesitter is unavailable or for letter lists
---@param line string Line to parse
---@param opts? markdown-plus.list.ParseOpts Optional parsing options
---@return markdown-plus.ListInfo|nil
local function parse_list_line_regex(line, opts)
  local skip_empty = opts and opts.skip_empty_patterns
  -- Try each pattern in order (checkbox variants first, then regular)
  for _, config in ipairs(PATTERN_CONFIG) do
    if skip_empty and config.is_empty then
      goto next_pattern
    end
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
    ::next_pattern::
  end

  return nil
end

---Check whether a parsed list item is an empty marker (marker at EOL, no trailing content)
---@param line string The line text
---@param list_info markdown-plus.ListInfo The parsed list info
---@return boolean True if the line contains only the marker with no trailing content
local function is_empty_marker(line, list_info)
  local after_marker = line:sub(#list_info.indent + #list_info.full_marker + 1)
  return after_marker == ""
end

---Parse a line to detect list information
---Uses treesitter when row is provided and available, falls back to regex
---@param line string Line to parse
---@param row? number Optional 1-indexed row for treesitter
---@param opts? markdown-plus.list.ParseOpts Optional parsing options (e.g., skip_empty_patterns)
---@return markdown-plus.ListInfo|nil List info or nil if not a list
function M.parse_list_line(line, row, opts)
  if not line then
    return nil
  end

  local skip_empty = opts and opts.skip_empty_patterns

  -- Try treesitter first (if row provided)
  local ts_result = row and parse_list_line_ts(row) or nil
  if ts_result then
    -- When skipping empty patterns, reject markers at EOL with no trailing content
    if skip_empty and is_empty_marker(line, ts_result) then
      return nil
    end
    return ts_result
  end

  -- Fall through to regex if ts returns nil
  -- (handles letter lists, ts unavailable, continuation lines, etc.)

  -- Fallback to regex
  return parse_list_line_regex(line, opts)
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
  local is_ordered = list_info.type == "ordered" or list_info.type == "ordered_paren"
  local is_letter_lower = list_info.type == "letter_lower" or list_info.type == "letter_lower_paren"
  local is_letter_upper = list_info.type == "letter_upper" or list_info.type == "letter_upper_paren"
  local delimiter = list_info.marker:match("[%.%)]$")

  if is_ordered or is_letter_lower or is_letter_upper then
    -- Check for previous list item at same indent
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line, row - 1)
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
