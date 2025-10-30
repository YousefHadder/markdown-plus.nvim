-- List input handlers module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local M = {}

---Extract content from a list line after the marker
---@param line string The line to extract from
---@param list_info table List information
---@return string Content after the marker
local function extract_list_content(line, list_info)
  local marker_end = #list_info.indent + #list_info.full_marker
  return line:sub(marker_end + 1):match("^%s*(.*)") or ""
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

  if not list_info then
    -- Not in a list, simulate default Enter behavior
    local line_before = current_line:sub(1, col)
    local line_after = current_line:sub(col + 1)

    utils.set_line(row, line_before)
    utils.insert_line(row + 1, line_after)
    utils.set_cursor(row + 1, 0)
    return
  end

  -- Check if current list item is empty
  if parser.is_empty_list_item(current_line, list_info) then
    -- Empty list item - break out of list
    M.break_out_of_list(list_info)
    return
  end

  -- Create next list item
  M.create_next_list_item(list_info)
end

---Handle Tab key for indentation
function M.handle_tab()
  local current_line = utils.get_current_line()
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, insert a tab character or spaces
    local cursor = utils.get_cursor()
    local row, col = cursor[1], cursor[2]
    local indent = string.rep(" ", vim.bo.shiftwidth or 2)
    local new_line = current_line:sub(1, col) .. indent .. current_line:sub(col + 1)
    utils.set_line(row, new_line)
    utils.set_cursor(row, col + #indent)
    return
  end

  -- Increase indentation
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
  local indent_size = vim.bo.shiftwidth

  local new_indent = list_info.indent .. string.rep(" ", indent_size)
  local content = extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)
  utils.set_cursor(row, col + indent_size)
end

---Handle Shift+Tab key for outdentation
function M.handle_shift_tab()
  local current_line = utils.get_current_line()
  local list_info = parser.parse_list_line(current_line)

  if not list_info then
    -- Not a list line: remove up to shiftwidth spaces from start
    local cursor = utils.get_cursor()
    local row, col = cursor[1], cursor[2]
    local indent_size = vim.bo.shiftwidth or 2
    local leading = current_line:match("^(%s*)")
    local to_remove = math.min(#leading, indent_size)
    if to_remove > 0 then
      local new_line = current_line:sub(to_remove + 1)
      utils.set_line(row, new_line)
      local new_col = math.max(0, col - to_remove)
      utils.set_cursor(row, new_col)
    end
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
  local content = extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)

  -- Adjust cursor position
  local new_col = math.max(0, col - indent_size)
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
      local new_line = current_line:sub(1, col - 1) .. current_line:sub(col + 1)
      utils.set_line(row, new_line)
      utils.set_cursor(row, col - 1)
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
    local content = extract_list_content(current_line, list_info)
    utils.set_line(row, list_info.indent .. content)
    utils.set_cursor(row, #list_info.indent)
    return
  end

  -- Default backspace in list content
  if col > 0 then
    local new_line = current_line:sub(1, col - 1) .. current_line:sub(col + 1)
    utils.set_line(row, new_line)
    utils.set_cursor(row, col - 1)
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
