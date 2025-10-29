-- Header manipulation module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.headers.parser")
local M = {}

---Promote header (decrease level number, increase importance)
---@return nil
function M.promote_header()
  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = parser.parse_header(line)

  if not header then
    vim.notify("Not on a header line", vim.log.levels.WARN)
    return
  end

  if header.level <= 1 then
    vim.notify("Already at highest level (H1)", vim.log.levels.INFO)
    return
  end

  -- Decrease level (remove one #)
  local new_level = header.level - 1
  local new_line = string.rep("#", new_level) .. " " .. header.text
  utils.set_line(line_num, new_line)

  vim.notify("Promoted to H" .. new_level, vim.log.levels.INFO)
end

---Demote header (increase level number, decrease importance)
---@return nil
function M.demote_header()
  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = parser.parse_header(line)

  if not header then
    vim.notify("Not on a header line", vim.log.levels.WARN)
    return
  end

  if header.level >= 6 then
    vim.notify("Already at lowest level (H6)", vim.log.levels.INFO)
    return
  end

  -- Increase level (add one #)
  local new_level = header.level + 1
  local new_line = string.rep("#", new_level) .. " " .. header.text
  utils.set_line(line_num, new_line)

  vim.notify("Demoted to H" .. new_level, vim.log.levels.INFO)
end

---Set specific header level (or convert line to header)
---@param level number Header level (1-6)
---@return nil
function M.set_header_level(level)
  if level < 1 or level > 6 then
    vim.notify("Invalid header level: " .. level, vim.log.levels.ERROR)
    return
  end

  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = parser.parse_header(line)

  if header then
    -- Already a header, change its level
    local new_line = string.rep("#", level) .. " " .. header.text
    utils.set_line(line_num, new_line)
    vim.notify("Changed to H" .. level, vim.log.levels.INFO)
  else
    -- Not a header, convert current line to header
    local text = line:match("^%s*(.-)%s*$") -- trim whitespace
    if text == "" then
      vim.notify("Cannot create header from empty line", vim.log.levels.WARN)
      return
    end
    local new_line = string.rep("#", level) .. " " .. text
    utils.set_line(line_num, new_line)
    vim.notify("Created H" .. level, vim.log.levels.INFO)
  end
end

return M
