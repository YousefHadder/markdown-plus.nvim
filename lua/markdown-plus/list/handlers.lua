-- List input handlers module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local M = {}

local CONTEXT_LOOKBACK = 100
local CONTEXT_LOOKAHEAD = 100
local MAX_LAST_ITEM_LOOKAHEAD = 50

---@type markdown-plus.InternalConfig
local config = {}

---Set module configuration
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg)
  config = cfg or {}
end

---Check whether smart outdent behavior is enabled (default: true)
---@return boolean
local function smart_outdent_enabled()
  return not (config.list and config.list.smart_outdent == false)
end

---Build the prefix string for a new list item (indent + marker + optional checkbox)
---@param indent string Indentation string
---@param marker string List marker (e.g., "-", "1.", "a)")
---@param checkbox string|nil Checkbox state (e.g., " ", "x") or nil if no checkbox
---@return string prefix The constructed list item prefix
local function build_list_prefix(indent, marker, checkbox)
  local prefix = indent .. marker .. " "
  if checkbox then
    prefix = prefix .. "[ ] "
  end
  return prefix
end

---Create a wrapper that skips the handler when inside a code block
---Falls through to default key behavior when in a code block
---@param handler function The original handler function
---@param fallback_key string The key to fall through to (e.g., "<CR>", "<Tab>")
---@return function Wrapped handler (not an expr mapping)
function M.skip_in_codeblock(handler, fallback_key)
  return function()
    if utils.is_in_code_block() then
      -- Feed the original key to get default behavior
      local key = vim.api.nvim_replace_termcodes(fallback_key, true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
      return
    end
    handler()
  end
end

---Find parent list item by looking upward from current line
---@param current_row number Current row number (1-indexed)
---@param current_line string Current line content
---@return table|nil, number|nil List info and row number of parent, or nil if not found
local function find_parent_list_item(current_row, current_line)
  local start_row = math.max(1, current_row - shared.MAX_PARENT_LOOKBACK)
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, current_row, false)
  local line_map = {}
  for idx, line in ipairs(lines) do
    line_map[start_row + idx - 1] = line
  end

  return shared.find_parent_list_item(current_line, current_row, line_map)
end

---Get a windowed line map keyed by absolute row number
---@param start_row number
---@param end_row number
---@return table<number, string>
local function get_line_window(start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local line_map = {}
  for idx, line in ipairs(lines) do
    line_map[start_row + idx - 1] = line
  end
  return line_map
end

---Get context lines around a row as an absolute-row map
---@param row number
---@param lookback number
---@param lookahead number
---@return table<number, string> lines_by_row
---@return number line_count
local function get_context_lines(row, lookback, lookahead)
  local line_count = vim.api.nvim_buf_line_count(0)
  local start_row = math.max(1, row - lookback)
  local end_row = math.min(line_count, row + lookahead)
  local lines_by_row = get_line_window(start_row, end_row)
  return lines_by_row, line_count
end

---Break out of list (remove current empty item)
---@param list_info table List information
function M.break_out_of_list(list_info)
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Replace current line with just the indentation
  utils.set_line(row, list_info.indent)

  -- Position cursor at end of line
  utils.set_cursor(row, #list_info.indent)
end

---Create next list item
---@param list_info table List information
function M.create_next_list_item(list_info)
  local cursor = utils.get_cursor()
  local row = cursor[1]

  local next_marker = parser.get_next_marker(list_info)
  local next_line = build_list_prefix(list_info.indent, next_marker, list_info.checkbox)

  -- Insert new line
  utils.insert_line(row + 1, next_line)

  -- Move cursor to new line at end
  utils.set_cursor(row + 1, #next_line)
end

---Handle Enter key in lists
function M.handle_enter()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line, row)
  local is_continuation_line = false

  if not list_info then
    -- Not directly on a list item line - check if we're on a continuation line
    list_info = find_parent_list_item(row, current_line)
    is_continuation_line = list_info ~= nil

    if not list_info then
      -- Not in a list at all, simulate default Enter behavior
      -- Use UTF-8 safe split to handle multibyte characters correctly
      local line_before, line_after = utils.split_at_cursor(current_line, col)

      utils.set_line(row, line_before)
      utils.insert_line(row + 1, line_after)
      utils.set_cursor(row + 1, 0)
      return
    end
  end

  -- Check if current list item is empty
  if parser.is_empty_list_item(current_line, list_info) then
    -- Empty list item - break out of list
    M.break_out_of_list(list_info)
    return
  end

  -- Calculate where list content starts
  local marker_end = shared.get_content_start_col(list_info)

  -- For continuation lines, only split if there's meaningful content after cursor
  -- For list item lines, split if cursor is before the last character
  local should_split
  if is_continuation_line then
    -- On continuation line: only split if there's multiple characters of content after cursor
    -- This prevents splitting at the very end which would create a list item with just one char
    local content_after = current_line:sub(col + 1)
    local trimmed = content_after:match("^%s*(.*)") or ""
    -- Ensure both non-whitespace exists and trimmed content has multiple characters to avoid single-char list items
    should_split = content_after:match("%S") ~= nil and #trimmed > 1
  else
    -- On list item line: split if cursor is after marker and before last char
    should_split = col > marker_end and col <= #current_line - 1
  end

  if should_split then
    -- Split content at cursor position
    -- Use UTF-8 safe split to handle multibyte characters correctly
    local content_before, content_after = utils.split_at_cursor(current_line, col)

    -- Update current line with content before cursor
    utils.set_line(row, content_before)

    -- Create next list item with content after cursor
    local next_marker = parser.get_next_marker(list_info)
    local next_line = build_list_prefix(list_info.indent, next_marker, list_info.checkbox)
      .. content_after:match("^%s*(.*)")

    utils.insert_line(row + 1, next_line)
    -- Calculate cursor position on new line (after marker and optional checkbox)
    local new_cursor_col = #list_info.indent + #next_marker + 1
    if list_info.checkbox then
      new_cursor_col = new_cursor_col + 4 -- Add "[ ] " length
    end
    utils.set_cursor(row + 1, new_cursor_col)
    return
  end

  -- Cursor at end or near marker - create next list item
  M.create_next_list_item(list_info)
end

---Continue list content on next line with proper indentation
---Splits the line at cursor and creates a continuation line aligned with content start
function M.continue_list_content()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, simulate default Enter behavior
    -- Use UTF-8 safe split to handle multibyte characters correctly
    local line_before, line_after = utils.split_at_cursor(current_line, col)

    utils.set_line(row, line_before)
    utils.insert_line(row + 1, line_after)
    utils.set_cursor(row + 1, 0)
    return
  end

  -- Calculate the indentation for continuation (align with list content start)
  local marker_end = shared.get_content_start_col(list_info)

  -- Split line at cursor
  -- Use UTF-8 safe split to handle multibyte characters correctly
  local line_before, line_after = utils.split_at_cursor(current_line, col)

  -- Update current line
  utils.set_line(row, line_before)

  -- Create continuation line with proper indentation
  local continuation_indent = string.rep(" ", marker_end)
  local continuation_line = continuation_indent .. line_after:match("^%s*(.*)")

  utils.insert_line(row + 1, continuation_line)
  utils.set_cursor(row + 1, marker_end)
end

---Handle Tab key for indentation
function M.handle_tab()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, fall through to default Tab behavior
    local key = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Increase indentation
  local indent_size = vim.bo.shiftwidth

  local new_indent = list_info.indent .. string.rep(" ", indent_size)
  local content = shared.extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)
  utils.set_cursor(row, col + indent_size)
end

---Handle Shift+Tab key for outdentation
function M.handle_shift_tab()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not a list line, fall through to default Shift+Tab behavior
    local key = vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Decrease indentation
  local indent_size = vim.bo.shiftwidth

  -- Can't outdent if already at root level
  if #list_info.indent < indent_size then
    return
  end

  local new_indent = list_info.indent:sub(1, #list_info.indent - indent_size)
  local content = shared.extract_list_content(current_line, list_info)
  local new_marker = list_info.full_marker

  if smart_outdent_enabled() then
    local target_indent = #new_indent
    local lines, _ = get_context_lines(row, CONTEXT_LOOKBACK, 0)
    local parent_list = shared.find_parent_list_at_indent(row, target_indent, lines)
    if parent_list then
      new_marker = parser.get_next_marker(parent_list)
      if list_info.checkbox then
        new_marker = new_marker .. " [" .. list_info.checkbox .. "]"
      end
    end
  end

  local new_line = new_indent .. new_marker .. " " .. content

  utils.set_line(row, new_line)

  -- Adjust cursor position
  local marker_delta = #new_marker - #list_info.full_marker
  local new_col = math.max(0, col - indent_size + marker_delta)
  utils.set_cursor(row, new_col)
end

local function delete_prev_char(line, row, col)
  local char_idx = vim.fn.charidx(line, col)
  local prev_char_idx = char_idx - 1
  if prev_char_idx < 0 then
    return
  end
  local new_col = vim.fn.byteidx(line, prev_char_idx)
  vim.api.nvim_buf_set_text(0, row - 1, new_col, row - 1, col, { "" })
  utils.set_cursor(row, new_col)
end

---Handle Backspace key
function M.handle_backspace()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, default backspace behavior
    if col > 0 then
      delete_prev_char(current_line, row, col)
    elseif row > 1 then
      -- At start of line, join with previous line
      local prev_line = utils.get_line(row - 1)
      local joined_line = prev_line .. current_line
      vim.api.nvim_buf_set_lines(0, row - 2, row, false, { joined_line })
      utils.set_cursor(row - 1, #prev_line)
    end
    return
  end

  -- If at the start of list content, remove the list marker
  local marker_end_col = #list_info.indent + #list_info.full_marker + 1
  if col <= marker_end_col and col > #list_info.indent then
    -- Remove list marker, keep content
    local content = shared.extract_list_content(current_line, list_info)
    utils.set_line(row, list_info.indent .. content)
    utils.set_cursor(row, #list_info.indent)
    return
  end

  -- Default backspace in list content
  if col > 0 then
    delete_prev_char(current_line, row, col)
  end
end

---Handle normal mode 'o' key
---@param row number
---@param indent_level number
---@param lines table<number, string>
---@param max_scan_row number
---@return boolean
local function is_last_item_at_indent(row, indent_level, lines, max_scan_row)
  for i = row + 1, max_scan_row do
    local line = lines[i]
    if not line then
      return true
    end

    local next_list = parser.parse_list_line(line, i)
    if next_list then
      local next_indent = #next_list.indent
      if next_indent == indent_level then
        return false
      end
      if next_indent < indent_level then
        return true
      end
    else
      if line:match("^%s*$") then
        return true
      end

      local line_indent = #(line:match("^(%s*)") or "")
      if line_indent <= indent_level then
        return true
      end
    end
  end

  -- We intentionally bound scanning for performance and assume "last item"
  -- when no sibling or break is found in the lookahead window.
  return true
end

function M.handle_normal_o()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, insert blank line below and enter insert mode
    utils.insert_line(row + 1, "")
    utils.set_cursor(row + 1, 0)
    vim.cmd("startinsert")
    return
  end

  if smart_outdent_enabled() then
    local current_indent = #list_info.indent
    local indent_size = vim.bo.shiftwidth
    local lines, line_count = get_context_lines(row, CONTEXT_LOOKBACK, CONTEXT_LOOKAHEAD)
    local max_scan_row = math.min(line_count, row + MAX_LAST_ITEM_LOOKAHEAD)

    if current_indent >= indent_size and is_last_item_at_indent(row, current_indent, lines, max_scan_row) then
      local target_indent = current_indent - indent_size
      local parent_list = shared.find_parent_list_at_indent(row, target_indent, lines)

      if parent_list then
        local next_parent_marker = parser.get_next_marker(parent_list)
        local next_parent_line = build_list_prefix(parent_list.indent, next_parent_marker, parent_list.checkbox)

        utils.insert_line(row + 1, next_parent_line)
        utils.set_cursor(row + 1, #next_parent_line)
        vim.cmd("startinsert!")
        return
      end
    end
  end

  -- Create next list item below
  local next_marker = parser.get_next_marker(list_info)
  local next_line = build_list_prefix(list_info.indent, next_marker, list_info.checkbox)

  utils.insert_line(row + 1, next_line)
  utils.set_cursor(row + 1, #next_line)
  vim.cmd("startinsert!")
end

---Handle normal mode 'O' key
function M.handle_normal_O()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, insert blank line above and enter insert mode
    utils.insert_line(row, "")
    utils.set_cursor(row, 0)
    vim.cmd("startinsert")
    return
  end

  -- Insert list item above with previous marker
  local prev_marker = parser.get_previous_marker(list_info, row)
  local prev_line = build_list_prefix(list_info.indent, prev_marker, list_info.checkbox)

  utils.insert_line(row, prev_line)
  utils.set_cursor(row, #prev_line)
  vim.cmd("startinsert!")
end

return M
