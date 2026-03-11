-- Markdown element pattern matching, code block detection, and link/image builders
local M = {}

local buffer = require("markdown-plus.utils.buffer")

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
---@param extractor? fun(match: string, match_start: number, match_end: number): table|nil Optional function to extract data from match
---@return table|nil result The extracted data from extractor, or basic match info, or nil if no match at cursor
function M.find_pattern_at_cursor(pattern, extractor)
  local cursor = buffer.get_cursor()
  local line = buffer.get_current_line()
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

---Check if cursor is currently inside a fenced code block
---Uses treesitter when available, falls back to regex-based detection
---@return boolean True if cursor is inside a code block
function M.is_in_code_block()
  local ts = require("markdown-plus.treesitter")
  local ts_result = ts.is_in_fenced_code_block()
  if ts_result ~= nil then
    return ts_result
  end

  -- Fallback to regex-based detection
  -- Scans from buffer start to current line, toggling state on each fence
  local cursor = buffer.get_cursor()
  local current_row = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, current_row, false)

  local in_code_block = false
  for _, line in ipairs(lines) do
    if line:match("^%s*```") or line:match("^%s*~~~") then
      in_code_block = not in_code_block
    end
  end

  return in_code_block
end

---Build a set of line numbers that are inside fenced code blocks using regex
---Scans all provided lines and returns a table where keys are 1-indexed line
---numbers that fall inside (or on the boundary of) a fenced code block.
---@param lines string[] All lines to scan
---@return table<number, boolean> Set of line numbers inside code blocks
function M.get_code_block_lines(lines)
  local code_lines = {}
  local code_block_parser = require("markdown-plus.code_block.parser")
  local blocks = code_block_parser.find_all_blocks_in_lines(lines)

  for _, block in ipairs(blocks) do
    for row = block.start_line, block.end_line do
      code_lines[row] = true
    end
  end

  return code_lines
end

---Build a markdown link string: [text](url) or [text](url "title")
---@param link_text string Link text
---@param url string Link URL
---@param title? string Optional title
---@return string link The formatted markdown link
function M.build_markdown_link(link_text, url, title)
  if title and title ~= "" then
    local escaped_title = title:gsub('"', '\\"')
    return string.format('[%s](%s "%s")', link_text, url, escaped_title)
  end
  return string.format("[%s](%s)", link_text, url)
end

---Build a markdown image string: ![alt](url) or ![alt](url "title")
---@param alt string Alt text
---@param url string Image URL
---@param title? string Optional title
---@return string image The formatted markdown image
function M.build_markdown_image(alt, url, title)
  if title and title ~= "" then
    local escaped_title = title:gsub('"', '\\"')
    return string.format('![%s](%s "%s")', alt, url, escaped_title)
  end
  return string.format("![%s](%s)", alt, url)
end

return M
