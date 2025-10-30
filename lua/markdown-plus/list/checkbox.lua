-- Checkbox management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local M = {}

---Toggle checkbox on a specific line
---@param line_num number 1-indexed line number
function M.toggle_checkbox_on_line(line_num)
  local line = utils.get_line(line_num)
  if line == "" then
    return
  end

  local list_info = parser.parse_list_line(line)

  if not list_info then
    return -- Not a list item, do nothing
  end

  local new_line = M.toggle_checkbox_in_line(line, list_info)
  if new_line then
    utils.set_line(line_num, new_line)
  end
end

---Toggle checkbox state in a line
---@param line string The line content
---@param list_info table The parsed list information
---@return string|nil The modified line, or nil if no change
function M.toggle_checkbox_in_line(line, list_info)
  if list_info.checkbox then
    -- Has checkbox - toggle between checked/unchecked
    return M.replace_checkbox_state(line, list_info)
  else
    -- No checkbox - add one
    return M.add_checkbox_to_line(line, list_info)
  end
end

---Replace checkbox state in a line
---@param line string The line content
---@param list_info table The parsed list information
---@return string The modified line
function M.replace_checkbox_state(line, list_info)
  local indent = list_info.indent
  local marker = list_info.marker

  -- Find the checkbox pattern and extract the content after it
  local checkbox_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)%[.?%]%s*(.*)"

  local prefix, content = line:match(checkbox_pattern)

  if prefix and content ~= nil then
    local current_state = list_info.checkbox
    local new_state = (current_state == "x" or current_state == "X") and " " or "x"
    return prefix .. "[" .. new_state .. "] " .. content
  end

  return line
end

---Add checkbox to a line that doesn't have one
---@param line string The line content
---@param list_info table The parsed list information
---@return string The modified line
function M.add_checkbox_to_line(line, list_info)
  local indent = list_info.indent
  local marker = list_info.marker

  -- Pattern to match list item and capture content
  local list_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)(.*)"

  local prefix, content = line:match(list_pattern)

  if prefix and content ~= nil then
    return prefix .. "[ ] " .. content
  end

  return line
end

---Toggle checkbox on current line (normal mode)
function M.toggle_checkbox_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  M.toggle_checkbox_on_line(row)
end

---Toggle checkbox in visual range
function M.toggle_checkbox_range()
  local start_row = vim.fn.line("v")
  local end_row = vim.fn.line(".")

  if start_row == 0 or end_row == 0 then
    return
  end

  -- Ensure start is before end
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  for row = start_row, end_row do
    M.toggle_checkbox_on_line(row)
  end
end

---Toggle checkbox in insert mode (maintains cursor position)
function M.toggle_checkbox_insert()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local col = cursor[2]

  local old_line = utils.get_line(row)
  M.toggle_checkbox_on_line(row)

  -- Restore cursor position (adjusting for potential line length changes)
  local new_line = utils.get_line(row)

  -- Calculate the character delta to adjust cursor position
  local old_len = #old_line
  local new_len = #new_line
  local delta = new_len - old_len

  local new_col
  -- Adjust cursor position by the delta to maintain visual position
  if delta > 0 then
    -- Characters were added (e.g., checkbox added), move cursor forward
    new_col = math.min(col + delta, #new_line)
  elseif delta < 0 then
    -- Characters were removed (e.g., checkbox removed), move cursor backward
    new_col = math.max(0, col + delta)
    new_col = math.min(new_col, #new_line)
  else
    -- No change in length (e.g., toggling checkbox state)
    new_col = math.min(col, #new_line)
  end

  vim.api.nvim_win_set_cursor(0, { row, new_col })
end

return M
