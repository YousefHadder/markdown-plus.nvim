-- Treesitter integration module for markdown-plus.nvim format feature
-- Handles treesitter-based format detection and manipulation

local utils = require("markdown-plus.utils")
local patterns = require("markdown-plus.format.patterns")

local M = {}

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
  local node_type = patterns.ts_node_types[format_type]
  if not node_type then
    -- Format type not supported by treesitter (e.g., highlight, underline)
    return nil
  end

  if not M.is_available() then
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
  if not M.is_available() then
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

---Check if cursor is inside a fenced code block
---@return boolean|nil True if inside code block, false if not, nil if treesitter unavailable
function M.is_in_fenced_code_block()
  if not M.is_available() then
    return nil
  end

  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  if not ok_parser or not parser then
    return nil
  end
  parser:parse(true)

  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return nil
  end

  -- Find codeblock in ancestors
  while node do
    if node:type() == "fenced_code_block" then
      return true
    end
    node = node:parent()
  end

  return false
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
