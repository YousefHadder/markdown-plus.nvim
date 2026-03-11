-- Visual selection extraction with multi-byte awareness
local M = {}

local buffer = require("markdown-plus.utils.buffer")
local text = require("markdown-plus.utils.text")

---Get visual selection range
---@param include_col? boolean Whether to include column info (default: true)
---@return {start_row: number, end_row: number, start_col?: number, end_col?: number}
function M.get_visual_selection(include_col)
  include_col = include_col ~= false -- default true

  local mode = vim.fn.mode()

  -- If in visual mode, use current selection
  if mode:match("[vV\22]") then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")

    local start_row = start_pos[2]
    local start_col = start_pos[3]
    local end_row = end_pos[2]
    local end_col = end_pos[3]

    -- Ensure start comes before end
    if start_row > end_row or (start_row == end_row and start_col > end_col) then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end

    -- Handle line-wise visual mode
    if mode == "V" then
      start_col = 1
      local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
      end_col = #end_line
    else
      -- For character-wise (v) and block-wise (<C-v>) visual modes,
      -- adjust end_col to handle multi-byte characters
      -- getpos() returns the byte position of the first byte of a multi-byte character
      -- We need the byte position of the last byte for proper text extraction
      local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
      end_col = text.get_char_end_byte(end_line, end_col)
    end

    if include_col then
      return {
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
      }
    else
      return {
        start_row = start_row,
        end_row = end_row,
      }
    end
  else
    -- Use marks from previous visual selection
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_col = start_pos[3]
    local end_col = end_pos[3]

    -- Adjust end_col for multi-byte characters in previous visual selection
    local end_row = end_pos[2]
    local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
    end_col = text.get_char_end_byte(end_line, end_col)

    if include_col then
      return {
        start_row = start_pos[2],
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
      }
    else
      return {
        start_row = start_pos[2],
        end_row = end_row,
      }
    end
  end
end

---Get single-line visual selection info
---Exits visual mode, gets selection marks, and returns selection data
---@param element_name string Name of element for error messages (e.g., "links", "images")
---@return table|nil selection {start_row, start_col, end_col, text, line} or nil if invalid
function M.get_single_line_selection(element_name)
  -- Exit visual mode first to update marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Only support single line
  if start_row ~= end_row then
    buffer.notify("Multi-line " .. element_name .. " not supported", vim.log.levels.WARN)
    return nil
  end

  local line = buffer.get_line(start_row)

  -- Adjust end_col for multi-byte characters (getpos returns first byte of char)
  end_col = text.get_char_end_byte(line, end_col)

  -- Extract selected text (vim columns are 1-indexed)
  local selected_text = line:sub(start_col, end_col)

  -- Trim any whitespace
  selected_text = selected_text:match("^%s*(.-)%s*$")

  if selected_text == "" then
    buffer.notify("No text selected", vim.log.levels.WARN)
    return nil
  end

  return {
    start_row = start_row,
    start_col = start_col,
    end_col = end_col,
    text = selected_text,
    line = line,
  }
end

return M
