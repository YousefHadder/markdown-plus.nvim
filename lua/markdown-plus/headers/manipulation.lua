-- Header manipulation module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.headers.parser")
local M = {}

---Build setext underline for heading text
---@param level number Heading level (1 or 2)
---@param text string Heading text
---@return string
local function build_setext_underline(level, text)
  local marker = level == 1 and "=" or "-"
  return string.rep(marker, math.max(3, #text))
end

---Get heading context at cursor (supports cursor on setext underline line)
---@return table|nil header
---@return number line_num Heading text line number
local function get_header_context()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local line = utils.get_line(row)
  local next_line = utils.get_line(row + 1)
  local header = parser.parse_header(line, next_line)

  if header then
    return header, row
  end

  if row > 1 then
    local prev_line = utils.get_line(row - 1)
    local prev_header = parser.parse_header(prev_line, line)
    if prev_header and prev_header.style == "setext" then
      return prev_header, row - 1
    end
  end

  return nil, row
end

---Replace a setext heading at line with an ATX heading
---@param line_num number
---@param level number
---@param text string
---@return nil
local function set_setext_to_atx(line_num, level, text)
  local atx_line = string.rep("#", level) .. " " .. text
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num + 1, false, { atx_line })
  utils.set_cursor(line_num, 0)
end

---Convert an ATX heading line into setext style (replace 1 line with 2)
---@param line_num number
---@param level number
---@param text string
---@return nil
local function set_to_setext(line_num, level, text)
  local underline = build_setext_underline(level, text)
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { text, underline })
  utils.set_cursor(line_num, 0)
end

---Update an existing setext heading in-place (replace text + underline lines)
---@param line_num number
---@param level number
---@param text string
---@return nil
local function update_setext(line_num, level, text)
  utils.set_line(line_num, text)
  utils.set_line(line_num + 1, build_setext_underline(level, text))
  utils.set_cursor(line_num, 0)
end

---Promote header (decrease level number, increase importance)
---@return nil
function M.promote_header()
  local header, line_num = get_header_context()

  if not header then
    vim.notify("Not on a header line", vim.log.levels.WARN)
    return
  end

  if header.level <= 1 then
    if header.style == "setext" then
      set_setext_to_atx(line_num, 1, header.text)
      vim.notify("Converted to ATX H1", vim.log.levels.INFO)
      return
    end
    vim.notify("Already at highest level (H1)", vim.log.levels.INFO)
    return
  end

  local new_level = header.level - 1

  if header.style == "setext" then
    update_setext(line_num, new_level, header.text)
  else
    local new_line = string.rep("#", new_level) .. " " .. header.text
    utils.set_line(line_num, new_line)
  end

  vim.notify("Promoted to H" .. new_level, vim.log.levels.INFO)
end

---Demote header (increase level number, decrease importance)
---@return nil
function M.demote_header()
  local header, line_num = get_header_context()

  if not header then
    vim.notify("Not on a header line", vim.log.levels.WARN)
    return
  end

  if header.level >= 6 then
    vim.notify("Already at lowest level (H6)", vim.log.levels.INFO)
    return
  end

  local new_level = header.level + 1

  if header.style == "setext" then
    if new_level <= 2 then
      update_setext(line_num, new_level, header.text)
    else
      set_setext_to_atx(line_num, new_level, header.text)
    end
  else
    local new_line = string.rep("#", new_level) .. " " .. header.text
    utils.set_line(line_num, new_line)
  end

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

  local header, line_num = get_header_context()
  local line = utils.get_line(line_num)

  if header then
    local new_line = string.rep("#", level) .. " " .. header.text
    if header.style == "setext" then
      vim.api.nvim_buf_set_lines(0, line_num - 1, line_num + 1, false, { new_line })
      utils.set_cursor(line_num, 0)
    else
      utils.set_line(line_num, new_line)
    end
    vim.notify("Changed to H" .. level, vim.log.levels.INFO)
  else
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

---Toggle heading style between ATX and setext for current heading
---ATX H1/H2 <-> setext, setext H1/H2 -> ATX H1/H2
---@return nil
function M.toggle_atx_setext()
  local header, line_num = get_header_context()

  if not header then
    vim.notify("Not on a header line", vim.log.levels.WARN)
    return
  end

  if header.style == "atx" then
    if header.level > 2 then
      vim.notify("Only H1/H2 can be converted to setext style", vim.log.levels.WARN)
      return
    end
    set_to_setext(line_num, header.level, header.text)
    vim.notify("Converted to setext H" .. header.level, vim.log.levels.INFO)
    return
  end

  set_setext_to_atx(line_num, header.level, header.text)
  vim.notify("Converted to ATX H" .. header.level, vim.log.levels.INFO)
end

return M
