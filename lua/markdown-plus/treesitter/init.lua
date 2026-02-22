---Main treesitter support module, for ts assisted markdown parsing

local M = {}

-- Per-buffer cache to avoid redundant parse(true) calls within the same edit cycle
local _parse_cache = {}

-- Centralized definitions for all markdown treesitter node types used
---@class markdown-plus.ts.NodeTypes
M.nodes = {
  -- Block elements
  FENCED_CODE_BLOCK = "fenced_code_block",
  PARAGRAPH = "paragraph",
  HEADING = "heading",

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

  -- Link/image elements
  INLINE_LINK = "inline_link",
  FULL_REFERENCE_LINK = "full_reference_link",
  SHORTCUT_REFERENCE_LINK = "shortcut_reference_link",
  IMAGE = "image",

  -- Other block elements
  BLOCK_QUOTE = "block_quote",
  PIPE_TABLE = "pipe_table",
}

---Check if treesitter markdown parser is available for the current buffer
---@return boolean True if treesitter is available and can be used
function M.is_available()
  -- Check if vim.treesitter.get_node exists (Neovim 0.11+)
  if not vim.treesitter or not vim.treesitter.get_node then
    return false
  end

  -- Try to get the markdown parser for current buffer (markdown_inline is injected)
  local ok = pcall(vim.treesitter.get_parser, 0, "markdown")
  return ok
end

---Get the parsed markdown parser for current buffer
---Caches the parsed result per buffer changedtick to avoid redundant parse(true) calls
---@return vim.treesitter.LanguageTree|nil parser The parser or nil if unavailable
function M.get_parser()
  if not M.is_available() then
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local tick = vim.b[bufnr].changedtick
  local cached = _parse_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.parser
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then
    return nil
  end

  -- Parse with injections, to enable markdown_inline
  parser:parse(true)
  _parse_cache[bufnr] = { tick = tick, parser = parser }
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
---@param opts? {ignore_injections?: boolean} Options (default: ignore_injections=false)
---@return TSNode|nil node The node or nil if unavailable
function M.get_node_at_position(row, col, opts)
  local parser = M.get_parser()
  if not parser then
    return nil
  end
  col = col or 0
  local ok, node = pcall(
    vim.treesitter.get_node,
    { pos = { row - 1, col }, ignore_injections = (opts or {}).ignore_injections or false }
  )
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
---Uses a TS query instead of recursive tree-walk for better performance
---@param node_type string Node type to find (e.g. M.nodes.FENCED_CODE_BLOCK)
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

  local query_str = string.format("(%s) @t", node_type)
  local ok, query = pcall(vim.treesitter.query.parse, "markdown", query_str)
  if not ok or not query then
    return nil
  end

  local line_set = {}
  for _, node, _ in query:iter_captures(tree:root(), 0) do
    local start_row, _, end_row, _ = node:range()
    -- Mark all lines in range (convert to 1-indexed)
    -- end_row is exclusive in treesitter, so we go up to end_row (not end_row + 1)
    -- This means fence lines (``` openers and closers) are included, matching
    -- the regex fallback which also marks fence delimiter lines as "inside"
    for row = start_row + 1, end_row do
      line_set[row] = true
    end
  end
  return line_set
end

---Check if cursor is inside a fenced code block using treesitter
---Uses ignore_injections=true to stay in the markdown tree,
---since injected language parsers won't have fenced_code_block nodes
---@return boolean|nil True if inside code block, false if not, nil if treesitter unavailable
function M.is_in_fenced_code_block()
  local node = M.get_node_at_cursor({ ignore_injections = true })
  if not node then
    return nil
  end
  return M.find_ancestor(node, M.nodes.FENCED_CODE_BLOCK) ~= nil
end

return M
