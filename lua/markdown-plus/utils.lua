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

---Split a line at a byte column position, ensuring proper UTF-8 character boundaries.
---Splits BEFORE the character at the cursor position (character at cursor goes to 'after').
---Use this for line splitting operations (e.g., Enter key behavior).
---@param line string The line content
---@param byte_col number 0-indexed byte column (from nvim_win_get_cursor)
---@return string before Text before the cursor position
---@return string after Text from cursor position onwards (including character at cursor)
function M.split_at_cursor(line, byte_col)
  if #line == 0 then
    return "", ""
  end

  -- Handle cursor past end of line
  if byte_col >= #line then
    return line, ""
  end

  -- Convert 0-indexed byte offset to character index
  local char_idx = vim.fn.charidx(line, byte_col)
  if char_idx < 0 then
    -- Should not happen if byte_col < #line, but be safe
    return line, ""
  end

  -- Get byte position for start of current character
  local curr_char_byte = vim.fn.byteidx(line, char_idx)
  if curr_char_byte == -1 or curr_char_byte >= #line then
    -- Past end of line
    return line, ""
  end

  return line:sub(1, curr_char_byte), line:sub(curr_char_byte + 1)
end

---Split a line after the character at cursor position, ensuring proper UTF-8 character boundaries.
---Splits AFTER the character at the cursor position (character at cursor goes to 'before').
---Use this for insertion operations (e.g., inserting footnotes, links, images after current char).
---@param line string The line content
---@param byte_col number 0-indexed byte column (from nvim_win_get_cursor)
---@return string before Text up to and including the character at cursor
---@return string after Text after the character at cursor
function M.split_after_cursor(line, byte_col)
  if #line == 0 then
    return "", ""
  end

  -- Handle cursor past end of line
  if byte_col >= #line then
    return line, ""
  end

  -- Convert 0-indexed byte offset to character index
  local char_idx = vim.fn.charidx(line, byte_col)
  if char_idx < 0 then
    -- Should not happen if byte_col < #line, but be safe
    return line, ""
  end

  -- Get byte position for start of next character
  local next_char_byte = vim.fn.byteidx(line, char_idx + 1)
  if next_char_byte == -1 then
    -- char_idx is at or past last character, split at end
    return line, ""
  end

  return line:sub(1, next_char_byte), line:sub(next_char_byte + 1)
end

---Get the byte index of the last byte of a multi-byte character
---When vim.fn.getpos() returns a column position for a multi-byte character,
---it returns the byte index of the FIRST byte of that character.
---This function adjusts it to return the byte index of the LAST byte.
---@param line string The line content
---@param byte_col number The 1-indexed byte column from getpos()
---@return number The 1-indexed byte column of the last byte of the character
function M.get_char_end_byte(line, byte_col)
  if byte_col > #line then
    return #line
  end

  -- Convert 1-indexed byte position to 0-indexed for vim.str_utfindex
  local char_idx = vim.str_utfindex(line, byte_col - 1)

  -- Get the byte index of the next character (0-indexed)
  local success, next_byte = pcall(vim.str_byteindex, line, char_idx + 1)

  if success and next_byte then
    -- next_byte is 0-indexed and points to the start of next char
    -- We want the last byte of current char, which is next_byte (in 1-indexed terms)
    return next_byte
  else
    -- We're at the last character or beyond, return line length
    return #line
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
    else
      -- For character-wise (v) and block-wise (<C-v>) visual modes,
      -- adjust end_col to handle multi-byte characters
      -- getpos() returns the byte position of the first byte of a multi-byte character
      -- We need the byte position of the last byte for proper text extraction
      local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
      end_col = M.get_char_end_byte(end_line, end_col)
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

    local start_col = start_pos[3]
    local end_col = end_pos[3]

    -- Adjust end_col for multi-byte characters in previous visual selection
    local end_row = end_pos[2]
    local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
    end_col = M.get_char_end_byte(end_line, end_col)

    if include_col then
      return {
        start_row = start_pos[2],
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
      }
    else
      return {
        start_row = start_pos[2],
        end_row = end_row,
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

-- =============================================================================
-- Element utilities (shared by links, images, and similar modules)
-- =============================================================================

---@class markdown-plus.ElementMatch
---@field start_pos number 1-indexed start position in line
---@field end_pos number 1-indexed end position in line
---@field text string The matched text
---@field line_num number 1-indexed line number

---Find all matches of a pattern in the current line and return the one under cursor
---@param pattern string Lua pattern to search for
---@param extractor? fun(match: string, start_pos: number, end_pos: number): table|nil Optional function to extract data from match
---@return table|nil result The extracted data from extractor, or basic match info, or nil if no match at cursor
function M.find_pattern_at_cursor(pattern, extractor)
  local cursor = M.get_cursor()
  local line = M.get_current_line()
  local col = cursor[2] -- 0-indexed column

  local init = 1
  while true do
    local match_start, match_end = line:find(pattern, init)
    if not match_start then
      break
    end

    -- Check if cursor is within this match (convert to 0-indexed for comparison)
    local start_idx = match_start - 1
    local end_idx = match_end - 1

    if col >= start_idx and col <= end_idx then
      local matched_text = line:sub(match_start, match_end)

      -- If extractor provided, use it to extract data
      if extractor then
        local result = extractor(matched_text, match_start, match_end)
        if result then
          -- Add common fields if not present
          result.start_pos = result.start_pos or match_start
          result.end_pos = result.end_pos or match_end
          result.line_num = result.line_num or cursor[1]
          return result
        end
      else
        -- Return basic match info
        return {
          start_pos = match_start,
          end_pos = match_end,
          text = matched_text,
          line_num = cursor[1],
        }
      end
    end

    init = match_end + 1
  end

  return nil
end

---Find multiple patterns at cursor, returning the first match
---Useful when an element can have multiple formats (e.g., inline link vs reference link)
---@param patterns table[] Array of {pattern: string, extractor: function|nil} tables
---@return table|nil result The match result or nil
function M.find_patterns_at_cursor(patterns)
  for _, p in ipairs(patterns) do
    local result = M.find_pattern_at_cursor(p.pattern, p.extractor)
    if result then
      return result
    end
  end
  return nil
end

---Get single-line visual selection info
---Exits visual mode, gets selection marks, and returns selection data
---@param element_name string Name of element for error messages (e.g., "links", "images")
---@return table|nil selection {start_row, start_col, end_col, text, line} or nil if invalid
function M.get_single_line_selection(element_name)
  -- Exit visual mode first to update marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Only support single line
  if start_row ~= end_row then
    M.notify("Multi-line " .. element_name .. " not supported", vim.log.levels.WARN)
    return nil
  end

  local line = M.get_line(start_row)

  -- Extract selected text (vim columns are 1-indexed)
  local text = line:sub(start_col, end_col)

  -- Trim any whitespace
  text = text:match("^%s*(.-)%s*$")

  if text == "" then
    M.notify("No text selected", vim.log.levels.WARN)
    return nil
  end

  return {
    start_row = start_row,
    start_col = start_col,
    end_col = end_col,
    text = text,
    line = line,
  }
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

---Insert content at cursor position and move cursor after inserted content
---@param content string Content to insert
---@return nil
function M.insert_at_cursor(content)
  local cursor = M.get_cursor()
  local line = M.get_current_line()
  local col = cursor[2]

  -- Use UTF-8 safe split to handle multibyte characters correctly
  local before, after = M.split_after_cursor(line, col)
  local new_line = before .. content .. after
  M.set_line(cursor[1], new_line)

  -- Move cursor after the inserted content
  M.set_cursor(cursor[1], #before + #content)
end

return M
