-- List input handlers module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local M = {}

---Skips the handler when inside a codeblock, falling back to the default key behavior (E.g; backspace/tab)
---@param handler function
---@param fallback_key string
---@return function Wrapped handler
function M.skip_in_codeblock(handler, fallback_key)
  return function()
    if utils.is_in_code_block() then
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
  -- Get all buffer lines for the search
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return shared.find_parent_list_item(current_line, current_row, lines)
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

  -- Build next line
  local next_line = list_info.indent .. next_marker .. " "
  if list_info.checkbox then
    next_line = next_line .. "[ ] "
  end

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
  local list_info = parser.parse_list_line(current_line)
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
    local next_line = list_info.indent .. next_marker .. " "
    if list_info.checkbox then
      next_line = next_line .. "[ ] "
    end
    next_line = next_line .. content_after:match("^%s*(.*)")

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
  local list_info = parser.parse_list_line(current_line)

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
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, fall through to default Tab behavior
    local key = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Increase indentation
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
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
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not a list line, fall through to default Shift+Tab behavior
    local key = vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  -- Decrease indentation
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
  local indent_size = vim.bo.shiftwidth

  -- Can't outdent if already at root level
  if #list_info.indent < indent_size then
    return
  end

  local new_indent = list_info.indent:sub(1, #list_info.indent - indent_size)
  local content = shared.extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)

  -- Adjust cursor position
  local new_col = math.max(0, col - indent_size)
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

  -- Check if we're in a list
  local list_info = parser.parse_list_line(current_line)

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
function M.handle_normal_o()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, insert blank line below and enter insert mode
    utils.insert_line(row + 1, "")
    utils.set_cursor(row + 1, 0)
    vim.cmd("startinsert")
    return
  end

  -- Create next list item below
  local next_marker = parser.get_next_marker(list_info)
  local next_line = list_info.indent .. next_marker .. " "
  if list_info.checkbox then
    next_line = next_line .. "[ ] "
  end

  utils.insert_line(row + 1, next_line)
  utils.set_cursor(row + 1, #next_line)
  vim.cmd("startinsert!")
end

---Handle normal mode 'O' key
function M.handle_normal_O()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, insert blank line above and enter insert mode
    utils.insert_line(row, "")
    utils.set_cursor(row, 0)
    vim.cmd("startinsert")
    return
  end

  -- Insert list item above with previous marker
  local prev_marker = parser.get_previous_marker(list_info, row)
  local prev_line = list_info.indent .. prev_marker .. " "
  if list_info.checkbox then
    prev_line = prev_line .. "[ ] "
  end

  utils.insert_line(row, prev_line)
  utils.set_cursor(row, #prev_line)
  vim.cmd("startinsert!")
end

return M
