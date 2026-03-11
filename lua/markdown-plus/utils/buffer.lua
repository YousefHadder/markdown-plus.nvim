-- Buffer, cursor, and user interaction primitives
local M = {}

local text = require("markdown-plus.utils.text")

---Get current cursor position
---@return number[] {row, col} 1-indexed row, 0-indexed col
function M.get_cursor()
  return vim.api.nvim_win_get_cursor(0)
end

---Set cursor position
---@param row number 1-indexed row number
---@param col number 0-indexed column number
---@return nil
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

---Get current line content
---@return string Line content
function M.get_current_line()
  local row = M.get_cursor()[1]
  return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
end

---Get line content by line number (1-indexed)
---@param line_num number 1-indexed line number
---@return string Line content
function M.get_line(line_num)
  return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1] or ""
end

---Set line content by line number (1-indexed)
---@param line_num number 1-indexed line number
---@param content string New line content
---@return nil
function M.set_line(line_num, content)
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { content })
end

---Insert line at position (1-indexed)
---@param line_num number 1-indexed line number
---@param content string Line content to insert
---@return nil
function M.insert_line(line_num, content)
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num - 1, false, { content })
end

-- Check if current buffer is markdown (deprecated, kept for compatibility)
-- Note: This check is now redundant as the autocmd pattern already filters by filetype
---@return boolean True if buffer filetype is markdown
function M.is_markdown_buffer()
  return true
end

---Check whether HTML block awareness is enabled in config
---@param plugin_config? markdown-plus.InternalConfig
---@return boolean
function M.is_html_awareness_enabled(plugin_config)
  return not (plugin_config and plugin_config.features and plugin_config.features.html_block_awareness == false)
end

---Get lines within a specified row range (1-indexed)
---@param start_row number Start row (1-indexed)
---@param end_row number End row (1-indexed, inclusive)
---@return string[] Lines in the specified range
function M.get_lines_in_range(start_row, end_row)
  return vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
end

---Get text in a line range
---@param start_row number Start row (1-indexed)
---@param start_col number Start column (1-indexed)
---@param end_row number End row (1-indexed)
---@param end_col number End column (1-indexed)
---@return string Text in range
function M.get_text_in_range(start_row, start_col, end_row, end_col)
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  if #lines == 0 then
    return ""
  end

  if #lines == 1 then
    return lines[1]:sub(start_col, end_col)
  else
    local text_parts = {}
    table.insert(text_parts, lines[1]:sub(start_col))
    for i = 2, #lines - 1 do
      table.insert(text_parts, lines[i])
    end
    table.insert(text_parts, lines[#lines]:sub(1, end_col))
    return table.concat(text_parts, "\n")
  end
end

---Set text in a range
---@param start_row number Start row (1-indexed)
---@param start_col number Start column (1-indexed)
---@param end_row number End row (1-indexed)
---@param end_col number End column (1-indexed)
---@param new_text string New text to set
---@return nil
function M.set_text_in_range(start_row, start_col, end_row, end_col, new_text)
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    vim.notify("markdown-plus: Invalid range - start position is after end position", vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(new_text, "\n")

  if start_row == end_row then
    local line = M.get_line(start_row)
    local before = line:sub(1, start_col - 1)
    local after = line:sub(end_col + 1)
    local new_line = before .. new_text .. after
    M.set_line(start_row, new_line)
  else
    local first_line = M.get_line(start_row)
    local last_line = M.get_line(end_row)
    local before = first_line:sub(1, start_col - 1)
    local after = last_line:sub(end_col + 1)
    lines[1] = before .. lines[1]
    lines[#lines] = lines[#lines] .. after
    vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, lines)
  end
end

---Replace a range in a line with new content
---@param line_num number 1-indexed line number
---@param start_pos number 1-indexed start position
---@param end_pos number 1-indexed end position
---@param new_content string New content to insert
---@return nil
function M.replace_in_line(line_num, start_pos, end_pos, new_content)
  local line = M.get_line(line_num)
  local new_line = line:sub(1, start_pos - 1) .. new_content .. line:sub(end_pos + 1)
  M.set_line(line_num, new_line)
end

---Insert content after cursor position and move cursor after inserted content
---@param content string Content to insert
---@return nil
function M.insert_after_cursor(content)
  local cursor = M.get_cursor()
  local line = M.get_current_line()
  local col = cursor[2]

  -- Use UTF-8 safe split to handle multibyte characters correctly
  local before, after = text.split_after_cursor(line, col)
  local new_line = before .. content .. after
  M.set_line(cursor[1], new_line)

  -- Move cursor after the inserted content
  M.set_cursor(cursor[1], #before + #content)
end

---Prompt user for input with optional default
---@param prompt string Prompt message
---@param default? string Default value
---@param completion? string Completion type
---@return string|nil User input or nil if cancelled
function M.input(prompt, default, completion)
  local result
  if completion then
    result = vim.fn.input(prompt, default or "", completion)
  else
    result = vim.fn.input(prompt, default or "")
  end

  -- Return nil if user cancelled (pressed ESC)
  -- Note: vim.fn.input returns "" on both ESC and when user enters empty string
  -- We treat empty string as cancellation when no default is provided
  if result == "" and default == nil then
    return nil
  end

  -- If result is empty but we have a default, user accepted the default
  return result
end

---Prompt user for confirmation (y/n)
---@param prompt string Prompt message
---@param default? boolean Default value (true for yes, false for no)
---@return boolean True if user confirmed
function M.confirm(prompt, default)
  local default_str = default and " [Y/n] " or " [y/N] "
  local result = vim.fn.input(prompt .. default_str)

  if result == "" then
    return default or false
  end

  return result:lower():match("^y") ~= nil
end

---Show notification with appropriate level
---@param msg string Message to show
---@param level? number Log level (vim.log.levels.*)
---@return nil
function M.notify(msg, level)
  vim.notify("markdown-plus: " .. msg, level or vim.log.levels.INFO)
end

return M
