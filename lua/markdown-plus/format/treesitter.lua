-- Format-specific treesitter functions for markdown-plus.nvim
-- Shared treesitter utilities live in lua/markdown-plus/treesitter/init.lua

local ts = require("markdown-plus.treesitter")
local utils = require("markdown-plus.utils")
local patterns = require("markdown-plus.format.patterns")

local M = {}

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

  local node = ts.get_node_at_cursor({ ignore_injections = false })
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
  local node = ts.get_node_at_cursor({ ignore_injections = false })
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
  return ts.is_in_fenced_code_block()
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

--- FIXME: determine what is *actually* public API surface
M.log = ts.log
M.nodes = ts.nodes
M.is_available = ts.is_available
M.get_parser = ts.get_parser
M.get_node_at_cursor = ts.get_node_at_cursor
M.get_node_at_position = ts.get_node_at_position
M.find_ancestor = ts.find_ancestor
M.is_row_in_node_type = ts.is_row_in_node_type
M.get_lines_in_node_type = ts.get_lines_in_node_type
M.is_in_fenced_code_block = ts.is_in_fenced_code_block

-- Forward debug property reads/writes to the shared ts module
-- so that setting format.treesitter.debug = true actually enables logging
setmetatable(M, {
  __index = function(_, key)
    if key == "debug" then
      return ts.debug
    end
  end,
  __newindex = function(_, key, value)
    if key == "debug" then
      ts.debug = value
    else
      rawset(M, key, value)
    end
  end,
})

return M
