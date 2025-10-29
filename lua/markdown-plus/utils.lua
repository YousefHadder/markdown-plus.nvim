-- Common utilities for markdown-plus.nvim
local M = {}

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

---Delete line at position (1-indexed)
---@param line_num number 1-indexed line number
---@return nil
function M.delete_line(line_num)
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, {})
end

---Get indentation level of a line
---@param line string Line content
---@return number Number of indentation characters
function M.get_indent_level(line)
  local indent = line:match("^(%s*)")
  return #indent
end

---Get indentation string (spaces or tabs)
---@param level number Indentation level
---@return string Indentation string
function M.get_indent_string(level)
  if vim.bo.expandtab then
    return string.rep(" ", level * vim.bo.shiftwidth)
  else
    return string.rep("\t", math.floor(level / vim.bo.tabstop))
  end
end

-- Check if current buffer is markdown (deprecated, kept for compatibility)
-- Note: This check is now redundant as the autocmd pattern already filters by filetype
---@return boolean True if buffer filetype is markdown
function M.is_markdown_buffer()
  return true
end

---Safe string matching with nil check
---@param str? string String to match
---@param pattern string Pattern to match against
---@return string|nil Matched string or nil
function M.safe_match(str, pattern)
  if not str then
    return nil
  end
  return str:match(pattern)
end

---Escape special regex characters
---@param str string String to escape
---@return string Escaped string
function M.escape_pattern(str)
  return str:gsub("([^%w])", "%%%1")
end

---Debug print (only when debug mode is enabled)
---@param ... any Values to print
---@return nil
function M.debug_print(...)
  if vim.g.markdown_plus_debug then
    print("[MarkdownPlus]", ...)
  end
end

---Get visual selection range
---@param include_col? boolean Whether to include column info (default: true)
---@return {start_row: number, end_row: number, start_col?: number, end_col?: number}
function M.get_visual_selection(include_col)
  include_col = include_col ~= false -- default true

  local mode = vim.fn.mode()

  -- If in visual mode, use current selection
  if mode:match("[vV\22]") then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")

    local start_row = start_pos[2]
    local start_col = start_pos[3]
    local end_row = end_pos[2]
    local end_col = end_pos[3]

    -- Ensure start comes before end
    if start_row > end_row or (start_row == end_row and start_col > end_col) then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end

    -- Handle line-wise visual mode
    if mode == "V" then
      start_col = 1
      local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
      end_col = #end_line
    end

    if include_col then
      return {
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
      }
    else
      return {
        start_row = start_row,
        end_row = end_row,
      }
    end
  else
    -- Use marks from previous visual selection
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    if include_col then
      return {
        start_row = start_pos[2],
        start_col = start_pos[3],
        end_row = end_pos[2],
        end_col = end_pos[3],
      }
    else
      return {
        start_row = start_pos[2],
        end_row = end_pos[2],
      }
    end
  end
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
    local text = {}
    table.insert(text, lines[1]:sub(start_col))
    for i = 2, #lines - 1 do
      table.insert(text, lines[i])
    end
    table.insert(text, lines[#lines]:sub(1, end_col))
    return table.concat(text, "\n")
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

---Prompt user for input with optional default
---@param prompt string Prompt message
---@param default? string Default value
---@param completion? string Completion type
---@return string|nil User input or nil if cancelled
function M.input(prompt, default, completion)
  local result = vim.fn.input(prompt, default or "", completion or "")

  -- Return nil if user cancelled (pressed ESC)
  if result == "" and not default then
    return nil
  end

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
