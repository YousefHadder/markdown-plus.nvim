-- TOC window orchestrator for markdown-plus.nvim
-- Slim entry point that delegates to toc_state, toc_render, and toc_actions.
local parser = require("markdown-plus.headers.parser")
local toc_state = require("markdown-plus.headers.toc_state")
local toc_render = require("markdown-plus.headers.toc_render")
local toc_actions = require("markdown-plus.headers.toc_actions")

local M = {}

---@type markdown-plus.InternalConfig
local config = {}

---Set module configuration
---@param cfg markdown-plus.InternalConfig
function M.set_config(cfg)
  config = cfg or {}
end

---Check if TOC window is currently open
---@return boolean
local function is_toc_open()
  if toc_state.state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.state.toc_winnr) then
    return true
  end
  return false
end

---Close the TOC window if it's open
---@return boolean True if window was closed
local function close_toc_window()
  if is_toc_open() then
    vim.api.nvim_win_close(toc_state.state.toc_winnr, true)
    toc_state.state.toc_winnr = nil
    return true
  end
  return false
end

---Auto-expand headers below initial_depth that have children
---@param headers table[] Parsed headers
---@param initial_depth number Depth threshold
local function auto_expand_headers(headers, initial_depth)
  for i, header in ipairs(headers) do
    if header.level < initial_depth then
      local has_children = false
      for j = i + 1, #headers do
        if headers[j].level > header.level then
          has_children = true
          break
        elseif headers[j].level <= header.level then
          break
        end
      end
      if has_children then
        toc_state.state.expanded_levels[i] = true
      end
    end
  end
end

---Create or reuse the TOC scratch buffer
---@return nil
local function ensure_toc_buffer()
  if toc_state.state.toc_bufnr and vim.api.nvim_buf_is_valid(toc_state.state.toc_bufnr) then
    return
  end

  toc_state.state.toc_bufnr = vim.api.nvim_create_buf(false, true)

  vim.bo[toc_state.state.toc_bufnr].buftype = "nofile"
  vim.bo[toc_state.state.toc_bufnr].bufhidden = "hide"
  vim.bo[toc_state.state.toc_bufnr].swapfile = false
  vim.bo[toc_state.state.toc_bufnr].modifiable = false
  vim.bo[toc_state.state.toc_bufnr].filetype = "markdown-toc"

  vim.api.nvim_buf_set_name(
    toc_state.state.toc_bufnr,
    "TOC: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(toc_state.state.source_bufnr), ":t")
  )
end

---Open the TOC split/tab window and configure its options
---@param window_type string Window type: 'vertical', 'horizontal', or 'tab'
local function open_toc_split(window_type)
  if window_type == "horizontal" then
    vim.cmd("split")
  elseif window_type == "vertical" then
    vim.cmd("vsplit")
  elseif window_type == "tab" then
    vim.cmd("tabnew")
  end

  toc_state.state.toc_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(toc_state.state.toc_winnr, toc_state.state.toc_bufnr)

  vim.wo[toc_state.state.toc_winnr].number = false
  vim.wo[toc_state.state.toc_winnr].relativenumber = false
  vim.wo[toc_state.state.toc_winnr].cursorline = true
  vim.wo[toc_state.state.toc_winnr].wrap = false
  vim.wo[toc_state.state.toc_winnr].signcolumn = "no"
  vim.wo[toc_state.state.toc_winnr].foldcolumn = "0"
  vim.wo[toc_state.state.toc_winnr].colorcolumn = ""

  vim.wo[toc_state.state.toc_winnr].statusline = toc_render.get_toc_statusline()
end

---Position cursor at the header closest to the source buffer cursor
---@param headers table[] Parsed headers
---@param source_cursor_line number Line number in the source buffer
local function position_cursor_at_closest(headers, source_cursor_line)
  local closest_idx = 1

  for i, header in ipairs(headers) do
    if header.line_num <= source_cursor_line then
      closest_idx = i
    else
      break
    end
  end

  for i, visible_header in ipairs(toc_state.state.visible_headers) do
    if visible_header.idx == closest_idx then
      vim.api.nvim_win_set_cursor(toc_state.state.toc_winnr, { i, 0 })
      break
    end
  end
end

---Open a navigable TOC in a custom buffer window
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
  local initial_depth = config.toc and config.toc.initial_depth or toc_state.TOC_DEFAULT_MAX_DEPTH

  -- Initialize state
  toc_state.state.source_bufnr = vim.api.nvim_get_current_buf()
  toc_state.state.headers = headers
  toc_state.state.expanded_levels = {}
  toc_state.state.visible_headers = {}
  toc_state.state.max_depth = initial_depth

  auto_expand_headers(headers, initial_depth)
  ensure_toc_buffer()
  open_toc_split(window_type)

  toc_render.setup_toc_highlights()
  toc_actions.setup_toc_keymaps(config)
  toc_render.render_toc()

  position_cursor_at_closest(headers, source_cursor_line)
end

return M
