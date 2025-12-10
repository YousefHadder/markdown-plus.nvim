-- Text formatting module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---State for dot-repeat operations
M._repeat_state = {
  format_type = nil,
}

---Register a mapping for dot-repeat support (for use with repeat.vim if available)
---@param plug string The plug mapping to register (e.g., "<Plug>(MarkdownPlusBold)")
---@return nil
function M.register_repeat(plug)
  if not plug then
    return
  end

  -- Check if repeat.vim is available
  local has_repeat = vim.fn.exists("*repeat#set") == 1
  if not has_repeat then
    return
  end

  -- Schedule the repeat registration to happen after current operation completes
  vim.schedule(function()
    local termcodes = vim.api.nvim_replace_termcodes(plug, true, true, true)
    vim.fn["repeat#set"](termcodes)
  end)
end

---Operatorfunc callback for dot-repeat support
---@return nil
function M._format_operatorfunc()
  if not M._repeat_state.format_type then
    return
  end

  -- Apply the formatting operation on the range
  M.toggle_format_word(M._repeat_state.format_type)
end

---Operatorfunc callback for clear formatting
---@return nil
function M._clear_operatorfunc()
  M.clear_formatting_word()
end

---Wrapper to make formatting dot-repeatable using operatorfunc
---@param format_type string The type of formatting to apply
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._toggle_format_with_repeat(format_type, plug)
  -- Save state for repeat
  M._repeat_state.format_type = format_type

  -- Set operatorfunc for the g@ operator
  vim.o.operatorfunc = "v:lua.require'markdown-plus.format'._format_operatorfunc"

  -- Register with repeat.vim if available
  if plug then
    M.register_repeat(plug)
  end

  -- Return g@l for linewise operation (operatorfunc will handle word detection)
  return "g@l"
end

---Wrapper to make clear formatting dot-repeatable
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._clear_with_repeat(plug)
  -- Set operatorfunc for the g@ operator
  vim.o.operatorfunc = "v:lua.require'markdown-plus.format'._clear_operatorfunc"

  -- Register with repeat.vim if available
  if plug then
    M.register_repeat(plug)
  end

  -- Return g@l for linewise operation (operatorfunc will handle word detection)
  return "g@l"
end

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
  highlight = { start = "==", end_pat = "==", wrap = "==" },
  underline = { start = "%+%+", end_pat = "%+%+", wrap = "++" },
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
          return M._toggle_format_with_repeat("bold", string.format("<Plug>(%s)", keymap_helper.plug_name("Bold")))
        end,
        function()
          M.toggle_format("bold")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mb", "<leader>mb" },
      desc = "Toggle bold formatting",
      expr = { true, false },
    },
    {
      plug = keymap_helper.plug_name("Italic"),
      fn = {
        function()
          return M._toggle_format_with_repeat("italic", string.format("<Plug>(%s)", keymap_helper.plug_name("Italic")))
        end,
        function()
          M.toggle_format("italic")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mi", "<leader>mi" },
      desc = "Toggle italic formatting",
      expr = { true, false },
    },
    {
      plug = keymap_helper.plug_name("Strikethrough"),
      fn = {
        function()
          return M._toggle_format_with_repeat(
            "strikethrough",
            string.format("<Plug>(%s)", keymap_helper.plug_name("Strikethrough"))
          )
        end,
        function()
          M.toggle_format("strikethrough")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>ms", "<leader>ms" },
      desc = "Toggle strikethrough formatting",
      expr = { true, false },
    },
    {
      plug = keymap_helper.plug_name("Code"),
      fn = {
        function()
          return M._toggle_format_with_repeat("code", string.format("<Plug>(%s)", keymap_helper.plug_name("Code")))
        end,
        function()
          M.toggle_format("code")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mc", "<leader>mc" },
      desc = "Toggle inline code formatting",
      expr = { true, false },
    },
    {
      plug = keymap_helper.plug_name("Highlight"),
      fn = {
        function()
          return M._toggle_format_with_repeat(
            "highlight",
            string.format("<Plug>(%s)", keymap_helper.plug_name("Highlight"))
          )
        end,
        function()
          M.toggle_format("highlight")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mh", "<leader>mh" },
      desc = "Toggle highlight formatting",
      expr = { true, false },
    },
    {
      plug = keymap_helper.plug_name("Underline"),
      fn = {
        function()
          return M._toggle_format_with_repeat(
            "underline",
            string.format("<Plug>(%s)", keymap_helper.plug_name("Underline"))
          )
        end,
        function()
          M.toggle_format("underline")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mu", "<leader>mu" },
      desc = "Toggle underline formatting",
      expr = { true, false },
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
        function()
          return M._clear_with_repeat(string.format("<Plug>(%s)", keymap_helper.plug_name("ClearFormatting")))
        end,
        function()
          M.clear_formatting()
        end,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mC", "<leader>mC" },
      desc = "Clear all formatting",
      expr = { true, false },
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
  local col = cursor[2] -- 0-indexed byte offset
  local line = utils.get_current_line()

  -- Define what characters are considered word boundaries (stop points)
  -- We want to stop at spaces and most punctuation, but NOT:
  -- - hyphens (-) - for words like "test-with-hyphens"
  -- - dots (.) - for words like "test.with.dots"
  -- - underscores (_) - for words like "test_with_underscores"
  -- - formatting markers (*, `, ~, =, +) - we need to include them in selection
  local allowed_punctuation = "-._*`~=+"
  local function is_word_boundary(char)
    -- Empty or space is always a boundary
    if char == "" or char:match("%s") then
      return true
    end
    -- Punctuation except our allowed characters
    if char:match("%p") then
      -- Allow these characters as part of words
      if allowed_punctuation:find(char, 1, true) then
        return false
      end
      return true
    end
    return false
  end

  -- Convert byte offset to character index for iteration
  local char_idx = vim.fn.charidx(line, col)
  if char_idx < 0 then
    char_idx = 0
  end

  -- Get total character count
  local total_chars = vim.fn.strcharlen(line)

  -- Find word start (iterate backwards by character)
  local word_start_char = char_idx
  while word_start_char > 0 do
    local char = vim.fn.strcharpart(line, word_start_char, 1)
    if is_word_boundary(char) then
      word_start_char = word_start_char + 1
      break
    end
    word_start_char = word_start_char - 1
  end
  if word_start_char < 0 then
    word_start_char = 0
  end

  -- Find word end (iterate forwards by character)
  local word_end_char = char_idx + 1
  while word_end_char < total_chars do
    local char = vim.fn.strcharpart(line, word_end_char, 1)
    if is_word_boundary(char) then
      word_end_char = word_end_char - 1
      break
    end
    word_end_char = word_end_char + 1
  end
  if word_end_char >= total_chars then
    word_end_char = total_chars - 1
  end
  if word_end_char < 0 then
    word_end_char = 0
  end

  -- Convert character indices back to byte positions (1-indexed for get_text_in_range)
  local start_byte = vim.fn.byteidx(line, word_start_char)
  if start_byte == -1 then
    start_byte = 0
  end
  local end_byte = vim.fn.byteidx(line, word_end_char + 1)
  if end_byte == -1 then
    end_byte = #line
  else
    end_byte = end_byte - 1
  end

  return {
    row = row,
    start_col = start_byte + 1, -- Convert to 1-indexed
    end_col = end_byte + 1, -- Convert to 1-indexed
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

  -- Remove highlight
  new_text = new_text:gsub("==(.-)==", "%1") -- ==text==

  -- Remove underline
  new_text = new_text:gsub("%+%+(.-)%+%+", "%1") -- ++text++

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

  -- Remove highlight
  new_text = new_text:gsub("==(.-)==", "%1")

  -- Remove underline
  new_text = new_text:gsub("%+%+(.-)%+%+", "%1")

  -- Remove italic (after bold)
  new_text = new_text:gsub("%*(.-)%*", "%1")
  new_text = new_text:gsub("_(.-)_", "%1")

  -- Remove code
  new_text = new_text:gsub("`(.-)`", "%1")

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)
end

return M
