-- List parsing module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local ts = require("markdown-plus.treesitter")
local patterns = require("markdown-plus.list.patterns")
local markers = require("markdown-plus.list.markers")
local M = {}

-- Pattern data aliases (see list/patterns.lua)
local TS_MARKER_TYPES = patterns.TS_MARKER_TYPES
local TS_CHECKBOX_TYPES = patterns.TS_CHECKBOX_TYPES
local PATTERN_CONFIG = patterns.PATTERN_CONFIG

---List patterns for detection (re-exported for backwards compatibility)
---@type markdown-plus.list.Patterns
M.patterns = patterns.patterns

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
    -- Part of a multi-line list item but not its start (e.g. 4-space nested lists)
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

  -- Treesitter includes leading whitespace in the marker node, so split it off
  local indent = marker_text:match("^(%s*)") or ""
  marker_text = marker_text:sub(#indent + 1)

  -- Extract marker value
  local marker, list_type, delimiter
  if marker_type_info.type == "ordered" or marker_type_info.type == "ordered_paren" then
    marker = marker_text:match("(%d+)")
    if not marker then
      return nil
    end -- letter list, fall through to regex
    list_type = marker_type_info.type
    delimiter = marker_type_info.delimiter
  else
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

  -- Fall back to regex (letter lists, ts unavailable, continuation lines, etc.)
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

-- Re-export marker sequence utilities for backwards compatibility (extracted into list/markers.lua)
M.index_to_letter = markers.index_to_letter
M.next_letter = markers.next_letter
M.get_next_marker = markers.get_next_marker
M.get_previous_marker = markers.get_previous_marker

return M
