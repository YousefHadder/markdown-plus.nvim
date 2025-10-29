-- Text formatting module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Formatting pattern definition
---@class markdown-plus.format.Pattern
---@field start string Start pattern (Lua pattern)
---@field end_pat string End pattern (Lua pattern)
---@field wrap string Wrapper string

---Formatting patterns for different styles
---@type table<string, markdown-plus.format.Pattern>
M.patterns = {
  bold = { start = "%*%*", end_pat = "%*%*", wrap = "**" },
  italic = { start = "%*", end_pat = "%*", wrap = "*" },
  strikethrough = { start = "~~", end_pat = "~~", wrap = "~~" },
  code = { start = "`", end_pat = "`", wrap = "`" },
}

---Setup text formatting module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable formatting features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for text formatting
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("Bold"),
      fn = {
        function()
          M.toggle_format_word("bold")
        end,
        function()
          M.toggle_format("bold")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mb", "<leader>mb" },
      desc = "Toggle bold formatting",
    },
    {
      plug = keymap_helper.plug_name("Italic"),
      fn = {
        function()
          M.toggle_format_word("italic")
        end,
        function()
          M.toggle_format("italic")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mi", "<leader>mi" },
      desc = "Toggle italic formatting",
    },
    {
      plug = keymap_helper.plug_name("Strikethrough"),
      fn = {
        function()
          M.toggle_format_word("strikethrough")
        end,
        function()
          M.toggle_format("strikethrough")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>ms", "<leader>ms" },
      desc = "Toggle strikethrough formatting",
    },
    {
      plug = keymap_helper.plug_name("Code"),
      fn = {
        function()
          M.toggle_format_word("code")
        end,
        function()
          M.toggle_format("code")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mc", "<leader>mc" },
      desc = "Toggle inline code formatting",
    },
    {
      plug = keymap_helper.plug_name("CodeBlock"),
      fn = M.convert_to_code_block,
      modes = "x",
      default_key = "<leader>mw",
      desc = "Convert selection to code block",
    },
    {
      plug = keymap_helper.plug_name("ClearFormatting"),
      fn = {
        M.clear_formatting_word,
        M.clear_formatting,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mC", "<leader>mC" },
      desc = "Clear all formatting",
    },
  })
end

---Get text within a specified range.
---@param start_row number Start row
---@param end_row number End row
---@return string[] Lines in the specified range
function M.get_lines_in_range(start_row, end_row)
  return vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
end

-- Check if text has formatting
function M.has_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return false
  end

  local start_pattern = "^" .. pattern.start
  local end_pattern = pattern.end_pat .. "$"

  return text:match(start_pattern) ~= nil and text:match(end_pattern) ~= nil
end

-- Add formatting to text
function M.add_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return text
  end

  return pattern.wrap .. text .. pattern.wrap
end

-- Remove formatting from text
function M.remove_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return text
  end

  local start_pattern = "^" .. pattern.start
  local end_pattern = pattern.end_pat .. "$"

  text = text:gsub(start_pattern, "")
  text = text:gsub(end_pattern, "")

  return text
end

-- Toggle formatting on visual selection
function M.toggle_format(format_type)
  -- Get the current visual selection (works even on first selection due to vim.fn.getpos('v'))
  local selection = utils.get_visual_selection()
  local text = utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)

  local new_text
  if M.has_formatting(text, format_type) then
    new_text = M.remove_formatting(text, format_type)
  else
    new_text = M.add_formatting(text, format_type)
  end

  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode and clear the selection
  vim.cmd("normal! \033")
end

-- Get current word boundaries
function M.get_word_boundaries()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local col = cursor[2]
  local line = utils.get_current_line()

  -- Define what characters are considered word boundaries (stop points)
  -- We want to stop at spaces and most punctuation, but NOT:
  -- - hyphens (-) - for words like "test-with-hyphens"
  -- - dots (.) - for words like "test.with.dots"
  -- - underscores (_) - for words like "test_with_underscores"
  -- - formatting markers (*, `, ~) - we need to include them in selection
  local function is_word_boundary(char)
    -- Empty or space is always a boundary
    if char == "" or char:match("%s") then
      return true
    end
    -- Punctuation except our allowed characters
    if char:match("%p") then
      -- Allow these characters as part of words
      if char == "-" or char == "." or char == "_" or char == "*" or char == "`" or char == "~" then
        return false
      end
      return true
    end
    return false
  end

  -- Find word start
  local word_start = col
  while word_start > 0 do
    local char = line:sub(word_start, word_start)
    if is_word_boundary(char) then
      word_start = word_start + 1
      break
    end
    word_start = word_start - 1
  end
  if word_start == 0 then
    word_start = 1
  end

  -- Find word end
  local word_end = col + 1
  while word_end <= #line do
    local char = line:sub(word_end, word_end)
    if is_word_boundary(char) then
      word_end = word_end - 1
      break
    end
    word_end = word_end + 1
  end
  if word_end > #line then
    word_end = #line
  end

  return {
    row = row,
    start_col = word_start,
    end_col = word_end,
  }
end

-- Toggle formatting on current word
function M.toggle_format_word(format_type)
  local boundaries = M.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  local new_text
  if M.has_formatting(text, format_type) then
    new_text = M.remove_formatting(text, format_type)
  else
    new_text = M.add_formatting(text, format_type)
  end

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)

  -- Adjust cursor position
  local cursor = utils.get_cursor()
  utils.set_cursor(cursor[1], cursor[2])
end

-- Remove all formatting from visual selection
function M.clear_formatting()
  -- Get the current visual selection (works even on first selection due to vim.fn.getpos('v'))
  local selection = utils.get_visual_selection()
  local text = utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)

  -- Remove all formatting - must process in order from longest to shortest
  -- to avoid issues like ** becoming * after first pass
  local new_text = text

  -- Remove bold (must come before italic since ** contains *)
  new_text = new_text:gsub("%*%*(.-)%*%*", "%1") -- **text**
  new_text = new_text:gsub("__(.-)__", "%1") -- __text__

  -- Remove strikethrough
  new_text = new_text:gsub("~~(.-)~~", "%1") -- ~~text~~

  -- Remove italic (after bold to avoid breaking **)
  new_text = new_text:gsub("%*(.-)%*", "%1") -- *text*
  new_text = new_text:gsub("_(.-)_", "%1") -- _text_

  -- Remove code
  new_text = new_text:gsub("`(.-)`", "%1") -- `text`

  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode and clear the selection
  vim.cmd("normal! \033")
end

-- Convert visual selection to a code block
function M.convert_to_code_block()
  -- Check if text formatting feature is enabled
  if not M.config.features or not M.config.features.text_formatting then
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

  -- Exit visual mode and clear the selection
  vim.cmd("normal! \033")
end

-- Remove all formatting from current word
function M.clear_formatting_word()
  local boundaries = M.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  -- Remove all formatting - must process in order from longest to shortest
  local new_text = text

  -- Remove bold (must come before italic)
  new_text = new_text:gsub("%*%*(.-)%*%*", "%1")
  new_text = new_text:gsub("__(.-)__", "%1")

  -- Remove strikethrough
  new_text = new_text:gsub("~~(.-)~~", "%1")

  -- Remove italic (after bold)
  new_text = new_text:gsub("%*(.-)%*", "%1")
  new_text = new_text:gsub("_(.-)_", "%1")

  -- Remove code
  new_text = new_text:gsub("`(.-)`", "%1")

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)
end

return M
