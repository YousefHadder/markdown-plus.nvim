-- Treesitter integration module for markdown-plus.nvim
-- Provides shared treesitter helpers and format-specific functions

local utils = require("markdown-plus.utils")
local patterns = require("markdown-plus.format.patterns")

local M = {}

-- Centralized definitions for all markdown treesitter node types used
---@class markdown-plus.ts.NodeTypes
M.nodes = {
  -- Block elements
  FENCED_CODE_BLOCK = "fenced_code_block",
  PARAGRAPH = "paragraph",
  HEADING = "heading", -- Not currently used

  -- List elements
  LIST = "list",
  LIST_ITEM = "list_item",

  -- List markers (unordered)

  ----
  LIST_MARKER_MINUS = "list_marker_minus",
  ---+
  LIST_MARKER_PLUS = "list_marker_plus",
  ---*
  LIST_MARKER_STAR = "list_marker_star",

  -- List markers (ordered)
  --- A.
  LIST_MARKER_DOT = "list_marker_dot",
  --- A)
  LIST_MARKER_PARENTHESIS = "list_marker_parenthesis",

  -- Task list markers

  -- - [  ]
  TASK_LIST_MARKER_UNCHECKED = "task_list_marker_unchecked",
  -- - [x]
  TASK_LIST_MARKER_CHECKED = "task_list_marker_checked",

  -- Inline elements (from markdown_inline parser)
  INLINE = "inline",
  CODE_SPAN = "code_span",
  ---_text_
  EMPHASIS = "emphasis",
  ---**test**
  STRONG_EMPHASIS = "strong_emphasis",
  STRIKETHROUGH = "strikethrough",
}

---Check if treesitter markdown parser is available for the current buffer
---@return boolean True if treesitter is available and can be used
function M.is_available()
  -- Check if vim.treesitter.get_node exists (Neovim 0.9+)
  if not vim.treesitter or not vim.treesitter.get_node then
    return false
  end

  -- Try to get the markdown parser for current buffer (markdown_inline is injected)
  local ok = pcall(vim.treesitter.get_parser, 0, "markdown")
  return ok
end

---Get the parsed markdown parser for current buffer
---@return vim.treesitter.LanguageTree|nil parser The parser or nil if unavailable
function M.get_parser()
  if not M.is_available() then
    return nil
  end
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  if not ok or not parser then
    return nil
  end

  -- Parse with injections, to enable markdown_inline
  parser:parse(true)
  return parser
end

---Get treesitter node at cursor position
---@param opts? {ignore_injections?: boolean} Options (default: ignore_injections=false)
---@return TSNode|nil node The node or nil if unavailable
function M.get_node_at_cursor(opts)
  local parser = M.get_parser()
  if not parser then
    return nil
  end
  opts = opts or {}
  local ignore_injections = opts.ignore_injections
  if ignore_injections == nil then
    ignore_injections = false
  end
  local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = ignore_injections })
  if not ok then
    return nil
  end
  return node
end

---Get treesitter node at a specific position
---@param row number 1-indexed row
---@param col? number 0-indexed column (default: 0)
---@return TSNode|nil node The node or nil if unavailable
function M.get_node_at_position(row, col)
  local parser = M.get_parser()
  if not parser then
    return nil
  end
  col = col or 0
  local ok, node = pcall(vim.treesitter.get_node, { pos = { row - 1, col } })
  if not ok then
    return nil
  end
  return node
end

---Find ancestor node of a specific type
---@param node TSNode Starting node
---@param node_type string|string[] Node type(s) to find
---@return TSNode|nil ancestor The ancestor node or nil
function M.find_ancestor(node, node_type)
  if not node then
    return nil
  end
  local types = type(node_type) == "table" and node_type or { node_type }
  local type_set = {}
  for _, t in ipairs(types) do
    type_set[t] = true
  end

  while node do
    if type_set[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

---Check if a row is inside a node of a specific type
---@param row number 1-indexed row
---@param node_type string|string[] Node type(s) to check
---@return boolean|nil True/false if determined, nil if ts unavailable
function M.is_row_in_node_type(row, node_type)
  local node = M.get_node_at_position(row, 0)
  if not node then
    return nil
  end
  return M.find_ancestor(node, node_type) ~= nil
end

---Get set of line numbers inside nodes of a specific type
---Efficiently queries all nodes of the type and collects their line ranges
---@param node_type string Node type to find (M.nodes.FENCED_CODE_BLOCK)
---@return table<number, boolean>|nil Line number set (1-indexed), or nil if ts unavailable
function M.get_lines_in_node_type(node_type)
  local parser = M.get_parser()
  if not parser then
    return nil
  end

  local tree = parser:trees()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  local line_set = {}

  -- Recursively find all nodes of the target type
  local function collect_lines(node)
    if node:type() == node_type then
      local start_row, _, end_row, _ = node:range()
      -- Mark all lines in range (convert to 1-indexed)
      -- end_row is exclusive in treesitter, so we go up to end_row (not end_row + 1)
      for line = start_row + 1, end_row do
        line_set[line] = true
      end
    end
    for child in node:iter_children() do
      collect_lines(child)
    end
  end

  collect_lines(root)
  return line_set
end

---@class markdown-plus.format.NodeInfo
---@field node TSNode The treesitter node object
---@field start_row number Start row (1-indexed)
---@field start_col number Start column (1-indexed)
---@field end_row number End row (1-indexed)
---@field end_col number End column (inclusive, 1-indexed)

---Get the formatting node at cursor position using treesitter
---Returns the node and its range if cursor is inside a formatted region
---@param format_type string The format type to look for (bold, italic, etc.)
---@return markdown-plus.format.NodeInfo|nil node_info Node info or nil if not found
function M.get_formatting_node_at_cursor(format_type)
  local node_type = patterns.ts_node_types[format_type]
  if not node_type then
    -- Format type not supported by treesitter (e.g., highlight, underline)
    return nil
  end

  local node = M.get_node_at_cursor({ ignore_injections = false })
  if not node then
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
  local node = M.get_node_at_cursor({ ignore_injections = false })
  if not node then
    return nil
  end

  -- Build reverse lookup: node_type -> format_type
  local node_to_format = {}
  for fmt, node_type in pairs(patterns.ts_node_types) do
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

---Check if cursor is inside a fenced code block using treesitter
---@return boolean|nil True if inside code block, false if not, nil if treesitter unavailable
function M.is_in_fenced_code_block()
  local node = M.get_node_at_cursor()
  if not node then
    return nil
  end
  return M.find_ancestor(node, M.nodes.FENCED_CODE_BLOCK) ~= nil
end

---Remove formatting from a treesitter node range
---@param node_info markdown-plus.format.NodeInfo Node info from get_formatting_node_at_cursor
---@param format_type string The format type to remove
---@param remove_formatting_fn function Function to remove formatting from text
---@return boolean success True if formatting was removed
function M.remove_formatting_from_node(node_info, format_type, remove_formatting_fn)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return false
  end

  -- Get the text content of the node
  local text = utils.get_text_in_range(node_info.start_row, node_info.start_col, node_info.end_row, node_info.end_col)

  -- Remove the formatting
  local new_text = remove_formatting_fn(text, format_type)

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

return M
