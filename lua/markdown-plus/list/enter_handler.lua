-- Enter key handlers for list management
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local handler_utils = require("markdown-plus.list.handler_utils")

local M = {}

---Set module configuration (reserved for future use; keeps facade propagation uniform)
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg) -- luacheck: no unused args
  -- Enter handler currently delegates all config-dependent behavior to handler_utils.
  -- This stub keeps the set_config interface uniform across all handler sub-modules.
end

---Break out of list (remove current empty item)
---@param list_info table List information
---@return nil
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
---@return nil
function M.create_next_list_item(list_info)
  local cursor = utils.get_cursor()
  local row = cursor[1]

  local next_marker = parser.get_next_marker(list_info)
  local next_line = handler_utils.build_list_prefix(list_info.indent, next_marker, list_info.checkbox)

  -- Insert new line
  utils.insert_line(row + 1, next_line)

  -- Move cursor to new line at end
  utils.set_cursor(row + 1, #next_line)
end

---Handle Enter key in lists
---@return nil
function M.handle_enter()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line, row)
  local is_continuation_line = false

  if not list_info then
    -- Not directly on a list item line - check if we're on a continuation line
    list_info = handler_utils.find_parent_list_item(row, current_line)
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
    local next_line = handler_utils.build_list_prefix(list_info.indent, next_marker, list_info.checkbox)
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
---@return nil
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

return M
