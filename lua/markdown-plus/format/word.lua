-- Word boundary detection module for markdown-plus.nvim format feature
-- Handles detecting word boundaries for word-based formatting operations

local utils = require("markdown-plus.utils")

local M = {}

---Get current word boundaries
---@return table boundaries Table with row, start_col, end_col (1-indexed)
function M.get_word_boundaries()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local col = cursor[2] -- 0-indexed byte offset
  local line = utils.get_current_line()

  -- Define what characters are considered word boundaries (stop points)
  -- We want to stop at spaces and most punctuation, but NOT:
  -- - hyphens (-) - for words like "test-with-hyphens"
  -- - dots (.) - for words like "test.with.dots"
  -- - underscores (_) - for words like "test_with_underscores"
  -- - formatting markers (*, `, ~, =, +) - we need to include them in selection
  local allowed_punctuation = "-._*`~=+"
  local function is_word_boundary(char)
    -- Empty or space is always a boundary
    if char == "" or char:match("%s") then
      return true
    end
    -- Punctuation except our allowed characters
    if char:match("%p") then
      -- Allow these characters as part of words
      if allowed_punctuation:find(char, 1, true) then
        return false
      end
      return true
    end
    return false
  end

  -- Convert byte offset to character index for iteration
  local char_idx = vim.fn.charidx(line, col)
  if char_idx < 0 then
    char_idx = 0
  end

  -- Get total character count
  local total_chars = vim.fn.strcharlen(line)

  -- Find word start (iterate backwards by character)
  local word_start_char = char_idx
  while word_start_char > 0 do
    local char = vim.fn.strcharpart(line, word_start_char, 1)
    if is_word_boundary(char) then
      word_start_char = word_start_char + 1
      break
    end
    word_start_char = word_start_char - 1
  end
  if word_start_char < 0 then
    word_start_char = 0
  end

  -- Find word end (iterate forwards by character)
  local word_end_char = char_idx + 1
  while word_end_char < total_chars do
    local char = vim.fn.strcharpart(line, word_end_char, 1)
    if is_word_boundary(char) then
      word_end_char = word_end_char - 1
      break
    end
    word_end_char = word_end_char + 1
  end
  if word_end_char >= total_chars then
    word_end_char = total_chars - 1
  end
  if word_end_char < 0 then
    word_end_char = 0
  end

  -- Convert character indices back to byte positions (1-indexed for get_text_in_range)
  local start_byte = vim.fn.byteidx(line, word_start_char)
  if start_byte == -1 then
    start_byte = 0
  end
  local end_byte = vim.fn.byteidx(line, word_end_char + 1)
  if end_byte == -1 then
    end_byte = #line
  else
    end_byte = end_byte - 1
  end

  return {
    row = row,
    start_col = start_byte + 1, -- Convert to 1-indexed
    end_col = end_byte + 1, -- Convert to 1-indexed
  }
end

return M
