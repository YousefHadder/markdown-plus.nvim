local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.code_block.parser")

local M = {}

---Jump to the next fenced code block start line
---@return boolean
function M.next_block()
  local blocks = parser.find_all_blocks()
  if #blocks == 0 then
    utils.notify("No fenced code blocks found", vim.log.levels.INFO)
    return false
  end

  local current_row = utils.get_cursor()[1]
  for _, block in ipairs(blocks) do
    if block.start_line > current_row then
      utils.set_cursor(block.start_line, 0)
      return true
    end
  end

  utils.set_cursor(blocks[1].start_line, 0)
  return true
end

---Jump to the previous fenced code block start line
---@return boolean
function M.prev_block()
  local blocks = parser.find_all_blocks()
  if #blocks == 0 then
    utils.notify("No fenced code blocks found", vim.log.levels.INFO)
    return false
  end

  local current_row = utils.get_cursor()[1]
  for i = #blocks, 1, -1 do
    if blocks[i].start_line < current_row then
      utils.set_cursor(blocks[i].start_line, 0)
      return true
    end
  end

  utils.set_cursor(blocks[#blocks].start_line, 0)
  return true
end

return M
