-- Header parsing module for markdown-plus.nvim
local ts = require("markdown-plus.format.treesitter")

local M = {}

---Header pattern (matches # through ######)
M.header_pattern = "^(#+)%s+(.+)$"

-- Code fence pattern for regex fallback
local CODE_FENCE_PATTERN = "^%s*```"
local CODE_FENCE_TILDE_PATTERN = "^%s*~~~"

---Parse a line to extract header information
---@param line string Line to parse
---@return table|nil Header info {level, text, hashes} or nil if not a header
function M.parse_header(line)
  if not line then
    return nil
  end

  local hashes, text = line:match(M.header_pattern)
  if hashes and text then
    return {
      level = #hashes,
      text = text,
      hashes = hashes,
    }
  end

  return nil
end

---Build set of lines inside code blocks using regex (fallback)
---@param lines string[] Buffer lines
---@return table<number, boolean> Set of 1-indexed line numbers
local function get_code_block_lines_regex(lines)
  local code_lines = {}
  local in_code_block = false

  for i, line in ipairs(lines) do
    if line:match(CODE_FENCE_PATTERN) or line:match(CODE_FENCE_TILDE_PATTERN) then
      code_lines[i] = true -- fence line is part of block
      in_code_block = not in_code_block
    elseif in_code_block then
      code_lines[i] = true
    end
  end

  return code_lines
end

---Get all headers in the buffer (excluding code blocks)
---@return table[] Array of headers with {level, text, hashes, line_num, full_line}
function M.get_all_headers()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local headers = {}

  -- Get code block lines (try treesitter first, fallback to regex)
  local code_block_lines = ts.get_lines_in_node_type("fenced_code_block")
  if not code_block_lines then
    code_block_lines = get_code_block_lines_regex(lines)
  end

  for i, line in ipairs(lines) do
    -- Only parse headers if we're not inside a code block
    if not code_block_lines[i] then
      local header = M.parse_header(line)
      if header then
        header.line_num = i
        header.full_line = line
        table.insert(headers, header)
      end
    end
  end

  return headers
end

---Generate GitHub-compatible slug from header text
---@param text string Header text to convert to slug
---@return string Slug suitable for TOC anchors
function M.generate_slug(text)
  local slug = text

  -- Step 1: Remove markdown formatting (must be done before lowercase)
  slug = slug:gsub("%*%*(.-)%*%*", "%1") -- **bold**
  slug = slug:gsub("%*(.-)%*", "%1") -- *italic*
  slug = slug:gsub("`(.-)`", "%1") -- `code`
  slug = slug:gsub("~~(.-)~~", "%1") -- ~~strikethrough~~

  -- Step 2: Convert to lowercase
  slug = slug:lower()

  -- Step 3: Replace spaces with hyphens (before removing punctuation!)
  slug = slug:gsub("%s+", "-")

  -- Step 4: Remove punctuation (GitHub-compatible)
  -- Keep: alphanumeric, hyphens (-), underscores (_)
  -- Remove: & ! @ # $ % ^ * ( ) = + [ ] { } \ | ; : ' " < > ? / . ,
  slug = slug:gsub("[&!@#$%%^*()=+%[%]{}\\|;:'\",<>?/.]", "")

  -- Step 5: Remove leading/trailing hyphens
  slug = slug:gsub("^%-+", "")
  slug = slug:gsub("%-+$", "")

  return slug
end

return M
