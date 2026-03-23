-- TOC render module for markdown-plus.nvim
-- Handles rendering, formatting, and syntax highlighting for the TOC window.
local toc_state = require("markdown-plus.headers.toc_state")

local M = {}

---Format a header line for display in the TOC buffer
---@param visible_header table The visible header entry with header, has_children, is_expanded fields
---@return string Formatted line string
function M.format_header_line(visible_header)
  local header = visible_header.header
  local indent = string.rep("  ", header.level - 1)

  local fold_marker
  if visible_header.has_children then
    fold_marker = visible_header.is_expanded and "▼ " or "▶ "
  else
    fold_marker = "  "
  end

  -- Format: [H1] Title (max level is 6, so no padding needed)
  local level_indicator = string.format("[H%d] ", header.level)

  return indent .. fold_marker .. level_indicator .. header.text
end

---Render the TOC buffer contents and auto-resize the window
---@return nil
function M.render_toc()
  if not toc_state.state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.state.toc_bufnr) then
    return
  end

  toc_state.build_visible_headers()

  local lines = {}
  local max_len = 0

  for _, visible_header in ipairs(toc_state.state.visible_headers) do
    local line = M.format_header_line(visible_header)
    table.insert(lines, line)

    local line_len = vim.fn.strdisplaywidth(line)
    if line_len > max_len then
      max_len = line_len
    end
  end

  vim.bo[toc_state.state.toc_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(toc_state.state.toc_bufnr, 0, -1, false, lines)
  vim.bo[toc_state.state.toc_bufnr].modifiable = false
  vim.bo[toc_state.state.toc_bufnr].modified = false

  -- Auto-resize window
  if toc_state.state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.state.toc_winnr) then
    local win_width =
      math.min(max_len + toc_state.TOC_WINDOW_PADDING, math.floor(vim.o.columns * toc_state.TOC_MAX_WIDTH_RATIO))
    vim.api.nvim_win_set_width(toc_state.state.toc_winnr, win_width)
  end
end

---Get the TOC statusline string
---@return string Statusline format string with key hints
function M.get_toc_statusline()
  return "%#StatusLine# TOC %#StatusLineNC#│ l=expand  h=collapse  ⏎=jump  q=close  ?=help"
end

---Set up syntax highlighting for the TOC buffer
---@return nil
function M.setup_toc_highlights()
  if not toc_state.state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.state.toc_bufnr) then
    return
  end

  -- Define highlight groups (global)
  vim.cmd([[
    highlight default link TocLevel Comment
    highlight default link TocMarkerClosed Special
    highlight default link TocMarkerOpen Special
    highlight default link TocH1 Title
    highlight default link TocH2 Function
    highlight default link TocH3 String
    highlight default link TocH4 Type
    highlight default link TocH5 Identifier
    highlight default link TocH6 Constant
  ]])

  -- Set up syntax matches in the TOC buffer context
  vim.api.nvim_buf_call(toc_state.state.toc_bufnr, function()
    -- Enable syntax
    vim.cmd("syntax enable")
    vim.cmd("syntax clear")

    -- Match markers first (so they can be contained)
    vim.cmd([[syntax match TocMarkerClosed "▶" contained]])
    vim.cmd([[syntax match TocMarkerOpen "▼" contained]])
    vim.cmd([[syntax match TocLevel "\[H[1-6]\]" contained]])

    -- Match full lines by header level
    -- Use consistent pattern for all levels to handle whitespace/markers
    vim.cmd([[syntax match TocH1 "^.*\[H1\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH2 "^.*\[H2\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH3 "^.*\[H3\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH4 "^.*\[H4\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH5 "^.*\[H5\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH6 "^.*\[H6\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
  end)
end

return M
