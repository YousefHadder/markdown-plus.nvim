-- UTF-8 safe string manipulation utilities
local M = {}

---Escape special regex characters
---@param str string String to escape
---@return string Escaped string
function M.escape_pattern(str)
  return str:gsub("([^%w])", "%%%1")
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

return M
