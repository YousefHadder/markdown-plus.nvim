-- Text formatting module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

-- ESC character constant for consistency
local ESC = "\027"

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

---Treesitter node types for format detection (markdown_inline parser)
---@type table<string, string>
M.ts_node_types = {
  bold = "strong_emphasis",
  italic = "emphasis",
  strikethrough = "strikethrough",
  code = "code_span",
  -- highlight and underline are not supported by standard markdown_inline parser
}

---Check if treesitter markdown parser is available for the current buffer
---@return boolean True if treesitter is available and can be used
local function is_treesitter_available()
  -- Check if vim.treesitter.get_node exists (Neovim 0.9+)
  if not vim.treesitter or not vim.treesitter.get_node then
    return false
  end

  -- Try to get the markdown parser for current buffer (markdown_inline is injected)
  local ok = pcall(vim.treesitter.get_parser, 0, "markdown")
  return ok
end

---@class markdown-plus.format.NodeInfo
---@field node userdata The treesitter node object
---@field start_row number Start row (1-indexed)
---@field start_col number Start column (1-indexed)
---@field end_row number End row (1-indexed)
---@field end_col number End column (inclusive, 1-indexed)

---Get the formatting node at cursor position using treesitter
---Returns the node and its range if cursor is inside a formatted region
---@param format_type string The format type to look for (bold, italic, etc.)
---@return markdown-plus.format.NodeInfo|nil node_info Node info or nil if not found
function M.get_formatting_node_at_cursor(format_type)
  local node_type = M.ts_node_types[format_type]
  if not node_type then
    -- Format type not supported by treesitter (e.g., highlight, underline)
    return nil
  end

  if not is_treesitter_available() then
    return nil
  end

  -- Ensure the parser is started and parsed (including injections)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  if not ok_parser or not parser then
    return nil
  end
  -- Parse with injections to enable markdown_inline
  parser:parse(true)

  -- Get the treesitter node at cursor, including injected languages (markdown_inline)
  -- ignore_injections = false allows us to get nodes from the injected markdown_inline parser
  local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
  if not ok or not node then
    return nil
  end

  -- Walk up the tree to find the outermost format node of the target type
  -- This handles cases like nested strikethrough nodes (~~outer ~inner~ outer~~)
  local found_node = nil
  while node do
    if node:type() == node_type then
      found_node = node
    end
    node = node:parent()
  end

  if found_node then
    local start_row, start_col, end_row, end_col = found_node:range()
    return {
      node = found_node,
      start_row = start_row + 1, -- Convert to 1-indexed
      start_col = start_col + 1, -- Convert to 1-indexed
      end_row = end_row + 1, -- Convert to 1-indexed
      end_col = end_col, -- 0-indexed exclusive becomes 1-indexed inclusive (no increment needed)
    }
  end

  return nil
end

---Check if cursor is inside any formatted range (optimized single-pass)
---@param exclude_type string|nil Format type to exclude from check (optional)
---@return string|nil format_type The format type found, or nil if not in any format
function M.get_any_format_at_cursor(exclude_type)
  if not is_treesitter_available() then
    return nil
  end

  -- Get parser and parse once
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  if not ok_parser or not parser then
    return nil
  end
  parser:parse(true)

  -- Get node at cursor once
  local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
  if not ok or not node then
    return nil
  end

  -- Build reverse lookup: node_type -> format_type
  local node_to_format = {}
  for fmt, node_type in pairs(M.ts_node_types) do
    if fmt ~= exclude_type then
      node_to_format[node_type] = fmt
    end
  end

  -- Walk tree once, checking all format types
  while node do
    local found_format = node_to_format[node:type()]
    if found_format then
      return found_format
    end
    node = node:parent()
  end

  return nil
end

---Remove formatting from a treesitter node range
---@param node_info markdown-plus.format.NodeInfo Node info from get_formatting_node_at_cursor
---@param format_type string The format type to remove
---@return boolean success True if formatting was removed
function M.remove_formatting_from_node(node_info, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return false
  end

  -- Get the text content of the node
  local text = utils.get_text_in_range(node_info.start_row, node_info.start_col, node_info.end_row, node_info.end_col)

  -- Remove the formatting
  local new_text = M.remove_formatting(text, format_type)

  -- Calculate cursor adjustment: cursor should stay on the same logical character
  -- The formatting markers are removed from the start, so we need to shift cursor left
  local cursor = utils.get_cursor()
  local marker_length = #pattern.wrap -- Length of formatting marker (e.g., 2 for "**")
  local cursor_in_range = cursor[1] == node_info.start_row
    and cursor[2] >= (node_info.start_col - 1)
    and cursor[2] < (node_info.end_col - 1)

  -- Replace the text
  utils.set_text_in_range(node_info.start_row, node_info.start_col, node_info.end_row, node_info.end_col, new_text)

  -- Adjust cursor position if it was inside the formatted range
  if cursor_in_range then
    local new_col = cursor[2] - marker_length
    -- Ensure cursor doesn't go before the start of the (now unformatted) text
    if new_col < (node_info.start_col - 1) then
      new_col = node_info.start_col - 1
    end
    utils.set_cursor(cursor[1], new_col)
  end

  return true
end

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
---Check if text has specific formatting markers
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text has the specified formatting
function M.has_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return false
  end

  local start_pattern = "^" .. pattern.start
  local end_pattern = pattern.end_pat .. "$"

  return text:match(start_pattern) ~= nil and text:match(end_pattern) ~= nil
end

---Add formatting markers to text
---@param text string The text to format
---@param format_type string The format type to add
---@return string The formatted text
function M.add_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return text
  end

  return pattern.wrap .. text .. pattern.wrap
end

---Remove formatting markers from text
---@param text string The text to unformat
---@param format_type string The format type to remove
---@return string The unformatted text
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

---Strip all formatting markers from text
---Processes in order from longest to shortest markers to avoid breaking patterns
---@param text string The text to strip all formatting from
---@return string The text with all formatting removed
function M.strip_all_formatting(text)
  local result = text

  -- Remove bold (must come before italic since ** contains *)
  result = result:gsub("%*%*(.-)%*%*", "%1") -- **text**
  result = result:gsub("__(.-)__", "%1") -- __text__

  -- Remove strikethrough
  result = result:gsub("~~(.-)~~", "%1") -- ~~text~~

  -- Remove highlight
  result = result:gsub("==(.-)==", "%1") -- ==text==

  -- Remove underline
  result = result:gsub("%+%+(.-)%+%+", "%1") -- ++text++

  -- Remove italic (after bold to avoid breaking **)
  result = result:gsub("%*(.-)%*", "%1") -- *text*
  result = result:gsub("_(.-)_", "%1") -- _text_

  -- Remove code
  result = result:gsub("`(.-)`", "%1") -- `text`

  return result
end

---Check if text contains any instances of the specified formatting (not just wrapping)
---Unlike has_formatting() which checks if text is wrapped with markers,
---this checks if the formatting exists anywhere within the text.
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text contains the formatting anywhere
function M.contains_formatting(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return false
  end

  -- For italic, we need special handling to not match bold (**)
  -- We look for single * not preceded or followed by another *
  if format_type == "italic" then
    -- Match *text* where the * is not part of **
    -- Pattern: single * followed by non-*, then content, then single * not preceded by *
    -- Use a more careful approach: find all * pairs and check they're not **
    local i = 1
    while i <= #text do
      -- Find a * character
      local start_pos = text:find("%*", i)
      if not start_pos then
        break
      end

      -- Check if it's a single * (not part of **)
      local is_double_before = start_pos > 1 and text:sub(start_pos - 1, start_pos - 1) == "*"
      local is_double_after = text:sub(start_pos + 1, start_pos + 1) == "*"

      if not is_double_before and not is_double_after then
        -- This is a single *, look for closing single *
        local j = start_pos + 1
        while j <= #text do
          local end_pos = text:find("%*", j)
          if not end_pos then
            break
          end

          -- Check if the closing * is also single
          local end_is_double_before = text:sub(end_pos - 1, end_pos - 1) == "*"
          local end_is_double_after = text:sub(end_pos + 1, end_pos + 1) == "*"

          if not end_is_double_before and not end_is_double_after then
            -- Found a valid italic pair
            return true
          end
          j = end_pos + 1
        end
      end

      -- Move past this * (or ** if it was double)
      if is_double_after then
        i = start_pos + 2
      else
        i = start_pos + 1
      end
    end
    return false
  end

  -- For bold, we need to ensure we match ** not single *
  if format_type == "bold" then
    return text:match("%*%*.-%*%*") ~= nil
  end

  -- For other formats, use the standard pattern
  local search_pattern = pattern.start .. ".-" .. pattern.end_pat
  return text:match(search_pattern) ~= nil
end

---Strip a specific format type from text (removes all instances)
---Unlike strip_all_formatting() which removes all formats, this only removes
---the specified format type, preserving other formatting.
---@param text string The text to process
---@param format_type string The format type to strip
---@return string The text with the specific formatting removed
function M.strip_format_type(text, format_type)
  local pattern = M.patterns[format_type]
  if not pattern then
    return text
  end

  -- For italic, we need special handling to not strip bold (**)
  if format_type == "italic" then
    -- We need to carefully replace single * pairs without touching **
    -- Strategy: temporarily replace ** with a placeholder, strip *, restore **
    local placeholder = "\001\002" -- Use control characters as placeholder
    local result = text:gsub("%*%*", placeholder)
    result = result:gsub("%*(.-)%*", "%1")
    result = result:gsub(placeholder, "**")
    return result
  end

  -- For bold, make sure we're matching ** not single *
  if format_type == "bold" then
    return text:gsub("%*%*(.-)%*%*", "%1")
  end

  -- For other formats, use the standard pattern
  local gsub_pattern = pattern.start .. "(.-)" .. pattern.end_pat
  return text:gsub(gsub_pattern, "%1")
end

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
  if M.has_formatting(text, format_type) then
    -- Check if this is a simple case (single formatted region) or complex (multiple regions)
    -- If remove_formatting gives the same result as strip_format_type, it's a single region
    local removed = M.remove_formatting(text, format_type)
    local stripped = M.strip_format_type(text, format_type)

    if removed == stripped then
      -- Simple case: just remove the outer formatting
      utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, removed)
      vim.cmd("normal! " .. ESC)
      return
    end
    -- Otherwise, fall through to the strip-and-wrap logic below
  end

  -- Check if the selection is inside a larger formatted range using treesitter
  -- This handles the case where user selects "bold text" inside "**bold text**"
  local node_type = M.ts_node_types[format_type]
  if node_type then
    -- Save cursor position, move to selection start, check for containing format node
    local saved_cursor = utils.get_cursor()
    utils.set_cursor(selection.start_row, selection.start_col - 1) -- 0-indexed col

    local node_info = M.get_formatting_node_at_cursor(format_type)
    if node_info then
      -- Check if the formatted range fully contains the selection
      local contains_selection = node_info.start_row <= selection.start_row
        and node_info.end_row >= selection.end_row
        and (node_info.start_row < selection.start_row or node_info.start_col <= selection.start_col)
        and (node_info.end_row > selection.end_row or node_info.end_col >= selection.end_col)

      if contains_selection then
        -- Remove formatting from the entire containing range
        M.remove_formatting_from_node(node_info, format_type)
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
  if M.contains_formatting(text, format_type) then
    text_to_format = M.strip_format_type(text, format_type)
  end

  local new_text = M.add_formatting(text_to_format, format_type)
  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

---Get current word boundaries
---@return table boundaries Table with row, start_col, end_col (1-indexed)
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

---Toggle formatting on current word
---Uses treesitter to detect if cursor is inside an existing formatted range.
---If inside a formatted range of the SAME type, removes formatting from the entire range.
---Otherwise, adds the requested formatting to the current word.
---@param format_type string The format type to toggle
---@return nil
function M.toggle_format_word(format_type)
  -- First, try treesitter-based detection for the entire formatted range
  local node_info = M.get_formatting_node_at_cursor(format_type)
  if node_info then
    -- Cursor is inside a formatted range of the same type, remove it
    M.remove_formatting_from_node(node_info, format_type)
    return
  end

  -- Not in a formatted range of the requested type.
  -- Check if we're inside ANY other formatted range (e.g., adding italic to bold text)
  -- If so, we should ADD the new formatting, not try to detect/remove based on word boundaries
  -- Uses optimized single-pass check instead of calling get_formatting_node_at_cursor for each type
  local in_other_format = M.get_any_format_at_cursor(format_type) ~= nil

  -- Fallback to word-based toggling
  local boundaries = M.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  -- Get current cursor position before making changes
  local cursor = utils.get_cursor()
  local pattern = M.patterns[format_type]
  local marker_length = pattern and #pattern.wrap or 0

  local new_text
  local is_adding = false
  -- If we're inside another format type, always ADD the new formatting
  -- This prevents false positives where **bold** is detected as having italic
  if in_other_format then
    new_text = M.add_formatting(text, format_type)
    is_adding = true
  elseif M.has_formatting(text, format_type) then
    new_text = M.remove_formatting(text, format_type)
  else
    new_text = M.add_formatting(text, format_type)
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

  local new_text = M.strip_all_formatting(text)

  utils.set_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col, new_text)

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

---Convert visual selection to a code block
---@return nil
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

  -- Exit visual mode
  vim.cmd("normal! " .. ESC)
end

---Remove all formatting from current word
---@return nil
function M.clear_formatting_word()
  local boundaries = M.get_word_boundaries()
  local text = utils.get_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col)

  if text == "" then
    return
  end

  local new_text = M.strip_all_formatting(text)

  utils.set_text_in_range(boundaries.row, boundaries.start_col, boundaries.row, boundaries.end_col, new_text)
end

return M
