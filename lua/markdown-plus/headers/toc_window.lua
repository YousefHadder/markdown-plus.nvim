-- TOC window module for markdown-plus.nvim
local parser = require("markdown-plus.headers.parser")
local M = {}

local TOC_DEFAULT_MAX_DEPTH = 2 -- Default initial depth to show
local TOC_WINDOW_PADDING = 5 -- Extra padding for window width calculation
local TOC_MAX_WIDTH_RATIO = 0.5 -- Maximum window width as ratio of total columns

---@type markdown-plus.InternalConfig
local config = {}

---Set module configuration
---@param cfg markdown-plus.InternalConfig
function M.set_config(cfg)
  config = cfg or {}
end

-- State for TOC window
local toc_state = {
  source_bufnr = nil,
  toc_bufnr = nil,
  toc_winnr = nil,
  headers = {},
  expanded_levels = {}, -- Track which headers are expanded
  visible_headers = {}, -- Currently visible headers
  max_depth = TOC_DEFAULT_MAX_DEPTH, -- Initial depth to show
}

--- Check if a header's children should be visible
---@param header_idx number Index of the header in headers array
---@return boolean
local function is_expanded(header_idx)
  return toc_state.expanded_levels[header_idx] == true
end

--- Get children of a header
---@param header_idx number Index of the parent header
---@return table List of child header indices
local function get_children(header_idx)
  local children = {}
  local parent_level = toc_state.headers[header_idx].level

  for i = header_idx + 1, #toc_state.headers do
    local header = toc_state.headers[i]
    if header.level <= parent_level then
      break -- No more children
    end
    if header.level == parent_level + 1 then
      table.insert(children, i)
    end
  end

  return children
end

--- Build the visible headers list based on expansion state
local function build_visible_headers()
  toc_state.visible_headers = {}

  for i, header in ipairs(toc_state.headers) do
    -- Check if this header should be visible
    local should_show = false

    if header.level <= toc_state.max_depth then
      -- Within initial depth
      should_show = true
    else
      -- Check if any parent is expanded
      local parent_idx = nil
      for j = i - 1, 1, -1 do
        if toc_state.headers[j].level < header.level then
          parent_idx = j
          break
        end
      end

      if parent_idx and is_expanded(parent_idx) then
        -- Direct parent is expanded, check if we should show this level
        should_show = header.level <= toc_state.headers[parent_idx].level + 1
      end
    end

    if should_show then
      table.insert(toc_state.visible_headers, {
        idx = i,
        header = header,
        has_children = #get_children(i) > 0,
        is_expanded = is_expanded(i),
      })
    end
  end
end

--- Format a header line for display
---@param visible_header table The visible header entry
---@return string
local function format_header_line(visible_header)
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

--- Render the TOC buffer
local function render_toc()
  if not toc_state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.toc_bufnr) then
    return
  end

  build_visible_headers()

  local lines = {}
  local max_len = 0

  for _, visible_header in ipairs(toc_state.visible_headers) do
    local line = format_header_line(visible_header)
    table.insert(lines, line)

    local line_len = vim.fn.strdisplaywidth(line)
    if line_len > max_len then
      max_len = line_len
    end
  end

  vim.bo[toc_state.toc_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(toc_state.toc_bufnr, 0, -1, false, lines)
  vim.bo[toc_state.toc_bufnr].modifiable = false
  vim.bo[toc_state.toc_bufnr].modified = false

  -- Auto-resize window
  if toc_state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.toc_winnr) then
    local win_width = math.min(max_len + TOC_WINDOW_PADDING, math.floor(vim.o.columns * TOC_MAX_WIDTH_RATIO))
    vim.api.nvim_win_set_width(toc_state.toc_winnr, win_width)
  end
end

--- Expand a header to show its children
local function expand_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]
  if not visible_header.has_children then
    return
  end

  -- Mark as expanded
  toc_state.expanded_levels[visible_header.idx] = true

  -- Re-render
  render_toc()
end

--- Collapse a header to hide its children
local function collapse_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]

  -- If already collapsed or expanded, collapse it
  if visible_header.is_expanded then
    toc_state.expanded_levels[visible_header.idx] = false
    render_toc()
    return
  end

  -- Otherwise, find parent and collapse it
  local header_idx = visible_header.idx
  local current_level = visible_header.header.level

  -- Find parent
  for i = header_idx - 1, 1, -1 do
    if toc_state.headers[i].level < current_level then
      -- Found parent, collapse it
      toc_state.expanded_levels[i] = false

      -- Find the parent's line in visible headers and move cursor there
      for j, vh in ipairs(toc_state.visible_headers) do
        if vh.idx == i then
          render_toc()
          vim.api.nvim_win_set_cursor(0, { j, 0 })
          return
        end
      end

      render_toc()
      return
    end
  end
end

--- Jump to the header in the source buffer
local function jump_to_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]
  local header = visible_header.header

  -- Find the window containing the source buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == toc_state.source_bufnr then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { header.line_num, 0 })
      vim.cmd("normal! zz") -- Center the line
      return
    end
  end
end

--- Show help popup for TOC window keybindings
local function show_toc_help()
  local help_lines = {
    "╔═══════════════════════════════════════╗",
    "║       TOC Navigation Help             ║",
    "╠═══════════════════════════════════════╣",
    "║                                       ║",
    "║  Movement:                            ║",
    "║    j/k       - Move cursor up/down    ║",
    "║    <Up/Down> - Move cursor up/down    ║",
    "║                                       ║",
    "║  Folding:                             ║",
    "║    l         - Expand header          ║",
    "║    h         - Collapse or go parent  ║",
    "║                                       ║",
    "║  Actions:                             ║",
    "║    <Enter>   - Jump to header         ║",
    "║    q         - Close TOC window       ║",
    "║    ?         - Toggle this help       ║",
    "║                                       ║",
    "║  Visual Indicators:                   ║",
    "║    ▶         - Collapsed (has child)  ║",
    "║    ▼         - Expanded (showing)     ║",
    "║    [H1]      - Header level           ║",
    "║                                       ║",
    "╚═══════════════════════════════════════╝",
  }

  -- Calculate popup dimensions
  local width = 43
  local height = #help_lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer for help
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
  })

  -- Set window options
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"

  -- Close on any key press
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "?", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

--- Set up keymaps for the TOC buffer
local function setup_toc_keymaps()
  local opts = { buffer = toc_state.toc_bufnr, silent = true, nowait = true }

  vim.keymap.set("n", "l", expand_header, vim.tbl_extend("force", opts, { desc = "Expand header" }))
  vim.keymap.set("n", "h", collapse_header, vim.tbl_extend("force", opts, { desc = "Collapse header" }))
  vim.keymap.set("n", "<CR>", jump_to_header, vim.tbl_extend("force", opts, { desc = "Jump to header" }))
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, vim.tbl_extend("force", opts, { desc = "Close TOC" }))
  vim.keymap.set("n", "?", show_toc_help, vim.tbl_extend("force", opts, { desc = "Show help" }))
end

--- Check if TOC window is currently open
---@return boolean
local function is_toc_open()
  if toc_state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.toc_winnr) then
    return true
  end
  return false
end

--- Close the TOC window if it's open
---@return boolean True if window was closed
local function close_toc_window()
  if is_toc_open() then
    vim.api.nvim_win_close(toc_state.toc_winnr, true)
    toc_state.toc_winnr = nil
    return true
  end
  return false
end

--- Get the TOC statusline string
---@return string
local function get_toc_statusline()
  return "%#StatusLine# TOC %#StatusLineNC#│ l=expand  h=collapse  ⏎=jump  q=close  ?=help"
end

--- Set up syntax highlighting for TOC buffer
local function setup_toc_highlights()
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
  vim.api.nvim_buf_call(toc_state.toc_bufnr, function()
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

--- Open a navigable TOC in a custom buffer window
---@param window_type? string Window type: 'vertical', 'horizontal', or 'tab' (default: 'vertical')
---@return nil
function M.open_toc_window(window_type)
  window_type = window_type or "vertical"

  -- Toggle: if already open, close it
  if is_toc_open() then
    close_toc_window()
    return
  end

  -- Get all headers
  local headers = parser.get_all_headers()

  if #headers == 0 then
    vim.notify("TOC: No headers found", vim.log.levels.WARN)
    return
  end

  -- Capture cursor position in source buffer before switching windows
  local source_cursor_line = vim.fn.line(".")

  -- Store state
  toc_state.source_bufnr = vim.api.nvim_get_current_buf()
  toc_state.headers = headers
  toc_state.expanded_levels = {}
  toc_state.visible_headers = {}
  toc_state.max_depth = config.toc and config.toc.initial_depth or TOC_DEFAULT_MAX_DEPTH

  -- Create or reuse TOC buffer
  if not toc_state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.toc_bufnr) then
    toc_state.toc_bufnr = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    vim.bo[toc_state.toc_bufnr].buftype = "nofile"
    vim.bo[toc_state.toc_bufnr].bufhidden = "hide"
    vim.bo[toc_state.toc_bufnr].swapfile = false
    vim.bo[toc_state.toc_bufnr].modifiable = false
    vim.bo[toc_state.toc_bufnr].filetype = "markdown-toc"

    -- Set buffer name
    vim.api.nvim_buf_set_name(
      toc_state.toc_bufnr,
      "TOC: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(toc_state.source_bufnr), ":t")
    )
  end

  -- Open window
  if window_type == "horizontal" then
    vim.cmd("split")
  elseif window_type == "vertical" then
    vim.cmd("vsplit")
  elseif window_type == "tab" then
    vim.cmd("tabnew")
  end

  toc_state.toc_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(toc_state.toc_winnr, toc_state.toc_bufnr)

  -- Set window options
  vim.wo[toc_state.toc_winnr].number = false
  vim.wo[toc_state.toc_winnr].relativenumber = false
  vim.wo[toc_state.toc_winnr].cursorline = true
  vim.wo[toc_state.toc_winnr].wrap = false
  vim.wo[toc_state.toc_winnr].signcolumn = "no"
  vim.wo[toc_state.toc_winnr].foldcolumn = "0"
  vim.wo[toc_state.toc_winnr].colorcolumn = ""

  -- Set a helpful status line
  vim.wo[toc_state.toc_winnr].statusline = get_toc_statusline()

  -- Set up syntax highlighting
  setup_toc_highlights()

  -- Set up keymaps
  setup_toc_keymaps()

  -- Initial render
  render_toc()

  -- Position cursor at header closest to source buffer cursor position
  local closest_idx = 1

  for i, header in ipairs(headers) do
    if header.line_num <= source_cursor_line then
      closest_idx = i
    else
      break
    end
  end

  -- Find the visible header index
  for i, visible_header in ipairs(toc_state.visible_headers) do
    if visible_header.idx == closest_idx then
      vim.api.nvim_win_set_cursor(toc_state.toc_winnr, { i, 0 })
      break
    end
  end
end

return M

