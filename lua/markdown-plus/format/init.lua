-- Text formatting module for markdown-plus.nvim
-- This is the main entry point that orchestrates all format sub-modules

local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")

-- Import sub-modules
local patterns = require("markdown-plus.format.patterns")
local detection = require("markdown-plus.format.detection")
local treesitter = require("markdown-plus.format.treesitter")
local word = require("markdown-plus.format.word")
local toggle = require("markdown-plus.format.toggle")
local repeat_module = require("markdown-plus.format.repeat")

local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

-- Re-export patterns and ts_node_types for backward compatibility
M.patterns = patterns.patterns
M.ts_node_types = patterns.ts_node_types

-- Re-export repeat state for backward compatibility
M._repeat_state = repeat_module._repeat_state

-- Initialize repeat module with toggle reference
repeat_module.set_toggle_module(toggle)

---Register a mapping for dot-repeat support (for use with repeat.vim if available)
---@param plug string The plug mapping to register (e.g., "<Plug>(MarkdownPlusBold)")
---@return nil
function M.register_repeat(plug)
  return repeat_module.register_repeat(plug)
end

---Operatorfunc callback for dot-repeat support
---@return nil
function M._format_operatorfunc()
  return repeat_module._format_operatorfunc()
end

---Operatorfunc callback for clear formatting
---@return nil
function M._clear_operatorfunc()
  return repeat_module._clear_operatorfunc()
end

---Wrapper to make formatting dot-repeatable using operatorfunc
---@param format_type string The type of formatting to apply
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._toggle_format_with_repeat(format_type, plug)
  return repeat_module._toggle_format_with_repeat(format_type, plug)
end

---Wrapper to make clear formatting dot-repeatable
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._clear_with_repeat(plug)
  return repeat_module._clear_with_repeat(plug)
end

---Get the formatting node at cursor position using treesitter
---@param format_type string The format type to look for (bold, italic, etc.)
---@return markdown-plus.format.NodeInfo|nil node_info Node info or nil if not found
function M.get_formatting_node_at_cursor(format_type)
  return treesitter.get_formatting_node_at_cursor(format_type)
end

---Check if cursor is inside any formatted range (optimized single-pass)
---@param exclude_type string|nil Format type to exclude from check (optional)
---@return string|nil format_type The format type found, or nil if not in any format
function M.get_any_format_at_cursor(exclude_type)
  return treesitter.get_any_format_at_cursor(exclude_type)
end

---Remove formatting from a treesitter node range
---@param node_info markdown-plus.format.NodeInfo Node info from get_formatting_node_at_cursor
---@param format_type string The format type to remove
---@return boolean success True if formatting was removed
function M.remove_formatting_from_node(node_info, format_type)
  return treesitter.remove_formatting_from_node(node_info, format_type, detection.remove_formatting)
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
      fn = function()
        M.convert_to_code_block()
      end,
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

-- Re-export detection functions for backward compatibility
---Check if text has specific formatting markers
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text has the specified formatting
function M.has_formatting(text, format_type)
  return detection.has_formatting(text, format_type)
end

---Add formatting markers to text
---@param text string The text to format
---@param format_type string The format type to add
---@return string The formatted text
function M.add_formatting(text, format_type)
  return detection.add_formatting(text, format_type)
end

---Remove formatting markers from text
---@param text string The text to unformat
---@param format_type string The format type to remove
---@return string The unformatted text
function M.remove_formatting(text, format_type)
  return detection.remove_formatting(text, format_type)
end

---Strip all formatting markers from text
---@param text string The text to strip all formatting from
---@return string The text with all formatting removed
function M.strip_all_formatting(text)
  return detection.strip_all_formatting(text)
end

---Check if text contains any instances of the specified formatting (not just wrapping)
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text contains the formatting anywhere
function M.contains_formatting(text, format_type)
  return detection.contains_formatting(text, format_type)
end

---Strip a specific format type from text (removes all instances)
---@param text string The text to process
---@param format_type string The format type to strip
---@return string The text with the specific formatting removed
function M.strip_format_type(text, format_type)
  return detection.strip_format_type(text, format_type)
end

-- Re-export toggle functions for backward compatibility
---Toggle formatting on visual selection
---@param format_type string The format type to toggle
---@return nil
function M.toggle_format(format_type)
  return toggle.toggle_format(format_type)
end

---Get current word boundaries
---@return table boundaries Table with row, start_col, end_col (1-indexed)
function M.get_word_boundaries()
  return word.get_word_boundaries()
end

---Toggle formatting on current word
---@param format_type string The format type to toggle
---@return nil
function M.toggle_format_word(format_type)
  return toggle.toggle_format_word(format_type)
end

---Remove all formatting from visual selection
---@return nil
function M.clear_formatting()
  return toggle.clear_formatting()
end

---Convert visual selection to a code block
---@return nil
function M.convert_to_code_block()
  return toggle.convert_to_code_block(M.config)
end

---Remove all formatting from current word
---@return nil
function M.clear_formatting_word()
  return toggle.clear_formatting_word()
end

return M
