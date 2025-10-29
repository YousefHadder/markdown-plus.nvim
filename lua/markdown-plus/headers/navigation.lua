-- Header navigation module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.headers.parser")
local M = {}

---Navigate to next header after cursor
---@return nil
function M.next_header()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]
  local headers = parser.get_all_headers()

  -- Find next header after current line
  for _, header in ipairs(headers) do
    if header.line_num > current_line then
      utils.set_cursor(header.line_num, 0)
      return
    end
  end

  -- No next header, stay at current position
  vim.notify("No next header", vim.log.levels.INFO)
end

---Navigate to previous header before cursor
---@return nil
function M.prev_header()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]
  local headers = parser.get_all_headers()

  -- Find previous header before current line (search backwards)
  for i = #headers, 1, -1 do
    local header = headers[i]
    if header.line_num < current_line then
      utils.set_cursor(header.line_num, 0)
      return
    end
  end

  -- No previous header, stay at current position
  vim.notify("No previous header", vim.log.levels.INFO)
end

---Follow link in TOC (jump to header from markdown link)
---@return boolean True if link was followed, false otherwise
function M.follow_link()
  local line = utils.get_current_line()

  -- Try to extract anchor from markdown link: [text](#anchor)
  local anchor = line:match("%[.-%]%(#(.-)%)")

  if not anchor then
    -- Not on a TOC link, don't do anything (let other mappings or default behavior handle it)
    return false
  end

  -- Convert anchor back to header text (reverse of slug generation)
  -- Anchors are lowercase with hyphens, need to find matching header
  local headers = parser.get_all_headers()

  for _, header in ipairs(headers) do
    local slug = parser.generate_slug(header.text)
    if slug == anchor then
      -- Found the matching header, jump to it
      utils.set_cursor(header.line_num, 0)
      -- Center the screen on the header
      vim.cmd("normal! zz")
      return true
    end
  end

  -- No matching header found
  vim.notify("Header not found: " .. anchor, vim.log.levels.WARN)
  return false
end

return M
