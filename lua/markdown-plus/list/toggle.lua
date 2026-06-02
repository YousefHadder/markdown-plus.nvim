-- List type toggling for markdown-plus.nvim
-- Toggle the current line (normal mode) or a visual selection between list types.
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local renumber = require("markdown-plus.list.renumber")

local M = {}

---Supported toggle target types and their family/metadata.
---@type table<string, {family: string, list_type?: string}>
local TYPE_DEFS = {
  unordered = { family = "unordered" },
  task = { family = "task" },
  ordered = { family = "orderable", list_type = "ordered" },
  ordered_paren = { family = "orderable", list_type = "ordered_paren" },
  letter_lower = { family = "orderable", list_type = "letter_lower" },
  letter_upper = { family = "orderable", list_type = "letter_upper" },
  letter_lower_paren = { family = "orderable", list_type = "letter_lower_paren" },
  letter_upper_paren = { family = "orderable", list_type = "letter_upper_paren" },
}

---@class markdown-plus.list.ToggleParts
---@field indent string Leading whitespace
---@field content string Text after the marker (or after indent for plain lines)
---@field checkbox string|nil Existing checkbox state, if any
---@field list_info markdown-plus.ListInfo|nil Parsed list info, or nil for plain lines

---Split a non-blank line into indent/content/checkbox parts.
---@param line string Line text
---@param row number 1-indexed row (for treesitter parsing)
---@return markdown-plus.list.ToggleParts
local function get_line_parts(line, row)
  local list_info = parser.parse_list_line(line, row)
  if list_info then
    return {
      indent = list_info.indent,
      content = shared.extract_list_content(line, list_info),
      checkbox = list_info.checkbox,
      list_info = list_info,
    }
  end

  local indent = line:match("^(%s*)") or ""
  return {
    indent = indent,
    content = line:sub(#indent + 1),
    checkbox = nil,
    list_info = nil,
  }
end

---Check whether a parsed line already matches the target type (for toggle-off).
---@param list_info markdown-plus.ListInfo|nil Parsed list info
---@param target_type string Target toggle type
---@return boolean
local function line_matches_target(list_info, target_type)
  if not list_info then
    return false
  end

  local def = TYPE_DEFS[target_type]
  if def.family == "unordered" then
    return list_info.type == "unordered" and list_info.checkbox == nil and list_info.marker == "-"
  elseif def.family == "task" then
    return list_info.type == "unordered" and list_info.checkbox ~= nil and list_info.marker == "-"
  end

  return list_info.type == def.list_type
end

---Normalize a checkbox capture into a single-character state.
---@param checkbox string|nil Captured checkbox state
---@return string
local function checkbox_state(checkbox)
  if checkbox and checkbox ~= "" then
    return checkbox
  end
  return " "
end

---Build the converted line for a given target type.
---For orderable types the marker is the type's first marker; sequential
---numbering is fixed afterwards by renumber.renumber_ordered_lists.
---@param parts markdown-plus.list.ToggleParts Parsed parts
---@param target_type string Target toggle type
---@return string
local function build_converted_line(parts, target_type)
  local def = TYPE_DEFS[target_type]
  local indent = parts.indent
  local content = parts.content

  if def.family == "unordered" then
    return indent .. "- " .. content
  elseif def.family == "task" then
    return indent .. "- [" .. checkbox_state(parts.checkbox) .. "] " .. content
  end

  -- Orderable: preserve an existing checkbox so e.g. "1. [x]" survives conversion.
  local marker = shared.get_marker_for_index(def.list_type, 1)
  if parts.checkbox then
    return indent .. marker .. " [" .. checkbox_state(parts.checkbox) .. "] " .. content
  end
  return indent .. marker .. " " .. content
end

---Build the cleared (plain text) line, dropping any marker and checkbox.
---@param parts markdown-plus.list.ToggleParts Parsed parts
---@return string
local function build_cleared_line(parts)
  return parts.indent .. parts.content
end

---Toggle the list type across a row range.
---@param start_row number 1-indexed start row
---@param end_row number 1-indexed end row
---@param target_type string Target toggle type
---@return nil
function M.toggle_list_in_range(start_row, end_row, target_type)
  if not TYPE_DEFS[target_type] then
    return
  end
  if not vim.bo.modifiable then
    return
  end

  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  -- Parse each line; remember blanks so they stay untouched.
  local entries = {}
  local nonblank = {}
  for idx, line in ipairs(lines) do
    local row = start_row + idx - 1
    if line:match("^%s*$") then
      entries[idx] = { blank = true }
    else
      local parts = get_line_parts(line, row)
      entries[idx] = { parts = parts }
      table.insert(nonblank, parts)
    end
  end

  if #nonblank == 0 then
    return
  end

  -- Range-level decision: clear only when every non-blank line already matches.
  local all_match = true
  for _, parts in ipairs(nonblank) do
    if not line_matches_target(parts.list_info, target_type) then
      all_match = false
      break
    end
  end
  local clearing = all_match

  local new_lines = {}
  for idx, line in ipairs(lines) do
    local entry = entries[idx]
    if entry.blank then
      new_lines[idx] = line
    elseif clearing then
      new_lines[idx] = build_cleared_line(entry.parts)
    else
      new_lines[idx] = build_converted_line(entry.parts, target_type)
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)

  -- Orderable conversions need sequential markers fixed per indent group.
  if not clearing and TYPE_DEFS[target_type].family == "orderable" then
    renumber.renumber_ordered_lists()
  end

  -- Toggle never changes the line count, so restore the cursor row directly.
  local line_count = vim.api.nvim_buf_line_count(0)
  local row = math.min(cursor[1], line_count)
  local row_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local col = math.min(cursor[2], math.max(0, #row_text))
  vim.api.nvim_win_set_cursor(0, { row, col })
end

---Toggle the list type on the current line (normal mode).
---@param target_type string Target toggle type
---@return nil
function M.toggle_list_line(target_type)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  M.toggle_list_in_range(row, row, target_type)
end

---Toggle the list type across the current visual selection.
---@param target_type string Target toggle type
---@return nil
function M.toggle_list_range(target_type)
  local start_row = vim.fn.line("v")
  local end_row = vim.fn.line(".")
  if start_row == 0 or end_row == 0 then
    return
  end
  M.toggle_list_in_range(start_row, end_row, target_type)
end

---Clear list markers (and checkboxes) from a row range, leaving plain text.
---Non-list lines and blank lines are left untouched.
---@param start_row number 1-indexed start row
---@param end_row number 1-indexed end row
---@return nil
function M.clear_list_in_range(start_row, end_row)
  if not vim.bo.modifiable then
    return
  end
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local new_lines = {}
  for idx, line in ipairs(lines) do
    if line:match("^%s*$") then
      new_lines[idx] = line
    else
      local parts = get_line_parts(line, start_row + idx - 1)
      new_lines[idx] = parts.list_info and build_cleared_line(parts) or line
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)

  local line_count = vim.api.nvim_buf_line_count(0)
  local row = math.min(cursor[1], line_count)
  local row_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  vim.api.nvim_win_set_cursor(0, { row, math.min(cursor[2], math.max(0, #row_text)) })
end

---Maps a picker key to a target toggle type. `c` is handled separately as clear.
---@type table<string, string>
M.KEY_MAP = {
  u = "unordered",
  t = "task",
  n = "ordered",
  N = "ordered_paren",
  l = "letter_lower",
  L = "letter_upper",
  p = "letter_lower_paren",
  P = "letter_upper_paren",
}

---Read a single keypress for the picker. Exposed so tests can stub it.
---@return string|nil key The pressed key, or nil on <Esc>/error
function M.read_key()
  local ok, ch = pcall(vim.fn.getcharstr)
  if not ok or ch == nil or ch == "" or ch == "\27" then
    return nil
  end
  return ch
end

---Dispatch a picker key to the matching operation over a row range.
---@param start_row number 1-indexed start row
---@param end_row number 1-indexed end row
---@return nil
local function dispatch_pick(start_row, end_row)
  local key = M.read_key()
  if not key then
    return
  end
  if key == "c" then
    M.clear_list_in_range(start_row, end_row)
    return
  end
  local target_type = M.KEY_MAP[key]
  if target_type then
    M.toggle_list_in_range(start_row, end_row, target_type)
  end
end

---Picker entry point for the current line (normal mode): prompts for a type key.
---@return nil
function M.toggle_list_pick_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  dispatch_pick(row, row)
end

---Picker entry point for the current visual selection: prompts for a type key.
---@return nil
function M.toggle_list_pick_range()
  local start_row = vim.fn.line("v")
  local end_row = vim.fn.line(".")
  if start_row == 0 or end_row == 0 then
    return
  end
  dispatch_pick(start_row, end_row)
end

-- Expose supported target types for callers/tests.
M.TYPE_DEFS = TYPE_DEFS

return M
