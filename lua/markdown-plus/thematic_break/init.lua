-- Thematic break management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

local THEMATIC_BREAK_PATTERN = "^%s*([%-_%*])%s*%1%s*%1[%-_%*%s]*$"
local DEFAULT_STYLE = "---"

---Setup thematic break module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable thematic break features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  M.setup_keymaps()
end

---Get configured insertion style with safe fallback
---@return "---"|"***"|"___"
local function get_insert_style()
  local style = M.config.thematic_break and M.config.thematic_break.style or DEFAULT_STYLE
  if style == "***" or style == "___" then
    return style
  end
  return DEFAULT_STYLE
end

---Detect whether a line is a thematic break
---@param line string
---@return string|nil marker "-", "*", "_" or nil
---@return string indent Leading whitespace on the line
local function get_thematic_break_marker(line)
  local marker = line:match(THEMATIC_BREAK_PATTERN)
  local indent = line:match("^(%s*)") or ""
  return marker, indent
end

---Set up keymaps for thematic break operations
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("InsertThematicBreak"),
      fn = M.insert,
      modes = "n",
      default_key = "<localleader>mh",
      desc = "Insert thematic break below cursor",
    },
    {
      plug = keymap_helper.plug_name("CycleThematicBreak"),
      fn = M.cycle_style,
      modes = "n",
      default_key = "<localleader>mH",
      desc = "Cycle thematic break style",
    },
  })
end

---Insert a thematic break below the cursor with surrounding blank lines when needed
---@return nil
function M.insert()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local style = get_insert_style()

  local current_line = utils.get_line(row) or ""
  local line_count = vim.api.nvim_buf_line_count(0)
  local next_line = row < line_count and utils.get_line(row + 1) or nil

  local needs_blank_above = current_line:match("^%s*$") == nil
  local needs_blank_below = next_line ~= nil and next_line:match("^%s*$") == nil

  local insert_lines = {}
  if needs_blank_above then
    table.insert(insert_lines, "")
  end
  table.insert(insert_lines, style)
  if needs_blank_below then
    table.insert(insert_lines, "")
  end

  vim.api.nvim_buf_set_lines(0, row, row, false, insert_lines)

  local break_row = row + (needs_blank_above and 2 or 1)
  utils.set_cursor(break_row, #style)
end

---Cycle thematic break style on the current line: --- -> *** -> ___ -> ---
---@return nil
function M.cycle_style()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local line = utils.get_line(row)
  local marker, indent = get_thematic_break_marker(line)

  if not marker then
    utils.notify("Current line is not a thematic break", vim.log.levels.WARN)
    return
  end

  local next_style = marker == "-" and "***" or marker == "*" and "___" or "---"
  local new_line = indent .. next_style
  utils.set_line(row, new_line)
  utils.set_cursor(row, #new_line)
end

return M
