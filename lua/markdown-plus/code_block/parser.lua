local utils = require("markdown-plus.utils")

local M = {}

---@class markdown-plus.CodeBlockInfo
---@field start_line number
---@field end_line number
---@field language string
---@field info_string string
---@field fence_char "`"|"~"
---@field fence_length number
---@field opening_indent string
---@field closing_indent string
---@field closing_fence_length number
---@field is_closed boolean

---@param line string
---@return {indent: string, fence_char: "`"|"~", fence_length: number, info_string: string, language: string}|nil
local function parse_opening_fence(line)
  local indent, fence, info = line:match("^(%s*)(`+)(.*)$")
  local fence_char = "`"
  if not fence then
    indent, fence, info = line:match("^(%s*)(~+)(.*)$")
    fence_char = "~"
  end

  if not fence or #fence < 3 then
    return nil
  end

  local info_string = vim.trim(info or "")
  local language = info_string:match("^(%S+)") or ""

  return {
    indent = indent or "",
    fence_char = fence_char,
    fence_length = #fence,
    info_string = info_string,
    language = language,
  }
end

---@param line string
---@param open_fence {fence_char: "`"|"~", fence_length: number}
---@return {indent: string, fence_length: number}|nil
local function parse_closing_fence(line, open_fence)
  local indent, fence, trailing
  if open_fence.fence_char == "`" then
    indent, fence, trailing = line:match("^(%s*)(`+)(%s*)$")
  else
    indent, fence, trailing = line:match("^(%s*)(~+)(%s*)$")
  end

  if not fence or #fence < open_fence.fence_length then
    return nil
  end

  if trailing and trailing:match("%S") then
    return nil
  end

  return {
    indent = indent or "",
    fence_length = #fence,
  }
end

---Find all fenced code blocks in the current buffer
---@return markdown-plus.CodeBlockInfo[]
function M.find_all_blocks()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = {}
  local i = 1

  while i <= #lines do
    local opening = parse_opening_fence(lines[i])
    if not opening then
      i = i + 1
    else
      local closing_line = nil
      local closing = nil
      for j = i + 1, #lines do
        closing = parse_closing_fence(lines[j], opening)
        if closing then
          closing_line = j
          break
        end
      end

      local end_line = closing_line or #lines
      table.insert(blocks, {
        start_line = i,
        end_line = end_line,
        language = opening.language,
        info_string = opening.info_string,
        fence_char = opening.fence_char,
        fence_length = opening.fence_length,
        opening_indent = opening.indent,
        closing_indent = closing and closing.indent or opening.indent,
        closing_fence_length = closing and closing.fence_length or opening.fence_length,
        is_closed = closing_line ~= nil,
      })

      i = end_line + 1
    end
  end

  return blocks
end

---Find the fenced code block containing the cursor
---@return markdown-plus.CodeBlockInfo|nil
function M.find_block_at_cursor()
  local row = utils.get_cursor()[1]
  local blocks = M.find_all_blocks()
  for _, block in ipairs(blocks) do
    if row >= block.start_line and row <= block.end_line then
      return block
    end
  end
  return nil
end

return M
