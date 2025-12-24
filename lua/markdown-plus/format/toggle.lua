-- Toggle formatting module for markdown-plus.nvim
-- Contains functions for toggling formatting on/off

local utils = require("markdown-plus.utils")
local patterns = require("markdown-plus.format.patterns")
local detection = require("markdown-plus.format.detection")
local treesitter = require("markdown-plus.format.treesitter")
local word = require("markdown-plus.format.word")

local M = {}

-- ESC character constant for consistency
local ESC = "\027"

---Toggle formatting on visual selection
---If the selection is entirely within a formatted range of the same type,
---removes the formatting from the entire containing range (smart toggle).
---If the selection contains existing same-type formatting, strips it and wraps the whole selection.
---Otherwise, toggles formatting on the selected text.
---@param format_type string The format type to toggle
---@return nil
function M.toggle_format(format_type)
  -- Get the current visual selection (works even on first selection due to vim.fn.getpos('v'))
  local selection = utils.get_visual_selection()
  local text = utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)

  -- First, check if the selection already has formatting markers wrapping it
  if detection.has_formatting(text, format_type) then
    -- Check if this is a simple case (single formatted region) or complex (multiple regions)
    -- If remove_formatting gives the same result as strip_format_type, it's a single region
    local removed = detection.remove_formatting(text, format_type)
    local stripped = detection.strip_format_type(text, format_type)

    if removed == stripped then
      -- Simple case: just remove the outer formatting
      utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, removed)
      vim.cmd("normal! " .. ESC)
      return
    end
    -- Complex case (multiple/nested regions): skip treesitter check, go directly to strip-and-wrap
    local new_text = detection.add_formatting(stripped, format_type)
    utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)
    vim.cmd("normal! " .. ESC)
    return
  end

  -- Check if the selection is inside a larger formatted range using treesitter
  -- This handles the case where user selects "bold text" inside "**bold text**"
  local node_type = patterns.ts_node_types[format_type]
  if node_type then
    -- Save cursor position, move to selection start, check for containing format node
    local saved_cursor = utils.get_cursor()
    utils.set_cursor(selection.start_row, selection.start_col - 1) -- 0-indexed col

    local node_info = treesitter.get_formatting_node_at_cursor(format_type)
    if node_info then
      -- Check if the formatted range fully contains the selection
      local contains_selection = node_info.start_row <= selection.start_row
        and node_info.end_row >= selection.end_row
        and (node_info.start_row < selection.start_row or node_info.start_col <= selection.start_col)
        and (node_info.end_row > selection.end_row or node_info.end_col >= selection.end_col)

      if contains_selection then
        -- Remove formatting from the entire containing range
        treesitter.remove_formatting_from_node(node_info, format_type, detection.remove_formatting)
        vim.cmd("normal! " .. ESC)
        return
      end
    end

    -- Restore cursor position
    utils.set_cursor(saved_cursor[1], saved_cursor[2])
  end

  -- Default behavior: add formatting to the selection
  -- But first, check if the selection contains any same-type formatting within it
  -- If so, strip that formatting first before wrapping (like Obsidian/Typora behavior)
  local text_to_format = text
  if detection.contains_formatting(text, format_type) then
    text_to_format = detection.strip_format_type(text, format_type)
  end

  local new_text = detection.add_formatting(text_to_format, format_type)
  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

---Toggle formatting on current word
---Uses treesitter to detect if cursor is inside an existing formatted range.
---If inside a formatted range of the SAME type, removes formatting from the entire range.
---Otherwise, adds the requested formatting to the current word.
---@param format_type string The format type to toggle
---@return nil
function M.toggle_format_word(format_type)
  -- First, try treesitter-based detection for the entire formatted range
  local node_info = treesitter.get_formatting_node_at_cursor(format_type)
  if node_info then
    -- Cursor is inside a formatted range of the same type, remove it
    treesitter.remove_formatting_from_node(node_info, format_type, detection.remove_formatting)
    return
  end

  -- Not in a formatted range of the requested type.
  -- Check if we're inside ANY other formatted range (e.g., adding italic to bold text)
  -- If so, we should ADD the new formatting, not try to detect/remove based on word boundaries
  -- Uses optimized single-pass check instead of calling get_formatting_node_at_cursor for each type
  local in_other_format = treesitter.get_any_format_at_cursor(format_type) ~= nil

  -- Fallback to word-based toggling
  local boundaries = word.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  -- Get current cursor position before making changes
  local cursor = utils.get_cursor()
  local pattern = patterns.patterns[format_type]
  local marker_length = pattern and #pattern.wrap or 0

  local new_text
  local is_adding = false
  -- If we're inside another format type, always ADD the new formatting
  -- This prevents false positives where **bold** is detected as having italic
  if in_other_format then
    new_text = detection.add_formatting(text, format_type)
    is_adding = true
  elseif detection.has_formatting(text, format_type) then
    new_text = detection.remove_formatting(text, format_type)
  else
    new_text = detection.add_formatting(text, format_type)
    is_adding = true
  end

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)

  -- Adjust cursor position to stay on the same logical character
  if is_adding then
    -- When adding formatting, cursor needs to shift right by marker length
    utils.set_cursor(cursor[1], cursor[2] + marker_length)
  else
    -- When removing formatting, cursor needs to shift left by marker length
    local new_col = cursor[2] - marker_length
    if new_col < (boundaries.start_col - 1) then
      new_col = boundaries.start_col - 1
    end
    utils.set_cursor(cursor[1], new_col)
  end
end

---Remove all formatting from visual selection
---@return nil
function M.clear_formatting()
  local selection = utils.get_visual_selection()
  local text = utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)

  local new_text = detection.strip_all_formatting(text)

  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

---Remove all formatting from current word
---@return nil
function M.clear_formatting_word()
  local boundaries = word.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  local new_text = detection.strip_all_formatting(text)

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)
end

---Convert visual selection to a code block
---@param config table Plugin configuration
---@return nil
function M.convert_to_code_block(config)
  -- Check if text formatting feature is enabled
  if not config.features or not config.features.text_formatting then
    utils.notify("Text formatting feature is disabled.", vim.log.levels.WARN)
    return
  end

  local selection = utils.get_visual_selection()
  local start_row, end_row = selection.start_row, selection.end_row

  -- Normalize start and end positions to ensure start_row <= end_row
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  -- Prompt for the language of the code block
  local lang = utils.input("Language for code block: ")
  -- User cancelled - silently return
  if not lang then
    return
  end

  -- Define code block markers
  local code_block_start = string.format("```%s", lang)
  local code_block_end = "```"

  -- Insert code block markers at the start and end of the selection
  vim.api.nvim_buf_set_lines(0, start_row - 1, start_row - 1, false, { code_block_start })
  vim.api.nvim_buf_set_lines(0, end_row + 1, end_row + 1, false, { code_block_end })

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

return M
