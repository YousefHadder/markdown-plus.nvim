-- TOC state module for markdown-plus.nvim
-- Manages shared state, constants, and pure state query functions for the TOC window.
local M = {}

M.TOC_DEFAULT_MAX_DEPTH = 2 -- Default initial depth to show
M.TOC_WINDOW_PADDING = 5 -- Extra padding for window width calculation
M.TOC_MAX_WIDTH_RATIO = 0.5 -- Maximum window width as ratio of total columns

---Shared mutable state for the TOC window.
---All modules share this single table reference via require() caching.
---Only mutate fields — never reassign M.state itself.
---@class markdown-plus.TocState
---@field source_bufnr number|nil Buffer number of the source markdown file
---@field toc_bufnr number|nil Buffer number of the TOC window
---@field toc_winnr number|nil Window number of the TOC window
---@field headers table[] Parsed headers from the source buffer
---@field expanded_levels table<number, boolean> Track which headers are expanded
---@field visible_headers table[] Currently visible headers after filtering
---@field max_depth number Current max depth for initial display
M.state = {
  source_bufnr = nil,
  toc_bufnr = nil,
  toc_winnr = nil,
  headers = {},
  expanded_levels = {},
  visible_headers = {},
  max_depth = M.TOC_DEFAULT_MAX_DEPTH,
}

---Check if a header's children should be visible
---@param header_idx number Index of the header in headers array
---@return boolean
function M.is_expanded(header_idx)
  return M.state.expanded_levels[header_idx] == true
end

---Get direct children of a header (one level deeper)
---@param header_idx number Index of the parent header
---@return number[] List of child header indices
function M.get_children(header_idx)
  local children = {}
  local parent_level = M.state.headers[header_idx].level

  for i = header_idx + 1, #M.state.headers do
    local header = M.state.headers[i]
    if header.level <= parent_level then
      break
    end
    if header.level == parent_level + 1 then
      table.insert(children, i)
    end
  end

  return children
end

---Check if all ancestors of a header are expanded
---@param header_idx number Index of the header in headers array
---@return boolean True if all ancestors are expanded (or no ancestors exist)
function M.are_all_ancestors_expanded(header_idx)
  local current_level = M.state.headers[header_idx].level

  -- H1 has no ancestors
  if current_level == 1 then
    return true
  end

  -- Walk backwards checking each ancestor in the chain
  for check_idx = header_idx - 1, 1, -1 do
    local check_header = M.state.headers[check_idx]

    -- Only care about direct parents (exactly one level up)
    if check_header.level == current_level - 1 then
      if not M.is_expanded(check_idx) then
        return false
      end
      -- Move up to check this ancestor's parents
      current_level = check_header.level
    end
  end

  return true
end

---Build the visible headers list based on expansion state
---@return nil
function M.build_visible_headers()
  M.state.visible_headers = {}

  for i, header in ipairs(M.state.headers) do
    local should_show

    -- Find direct parent (one level up)
    local parent_idx = nil
    for j = i - 1, 1, -1 do
      if M.state.headers[j].level == header.level - 1 then
        parent_idx = j
        break
      end
    end

    if header.level == 1 then
      -- H1 is always visible
      should_show = true
    elseif header.level <= M.state.max_depth then
      -- Within initial depth - show if all ancestors are expanded
      should_show = M.are_all_ancestors_expanded(i)
    else
      -- Beyond initial depth - only show if parent is expanded AND all ancestors are expanded
      should_show = parent_idx and M.is_expanded(parent_idx) and M.are_all_ancestors_expanded(i)
    end

    if should_show then
      table.insert(M.state.visible_headers, {
        idx = i,
        header = header,
        has_children = #M.get_children(i) > 0,
        is_expanded = M.is_expanded(i),
      })
    end
  end
end

return M
