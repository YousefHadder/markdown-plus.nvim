-- TOC actions module for markdown-plus.nvim
-- Handles user interactions and keymap registration for the TOC window.
local toc_state = require("markdown-plus.headers.toc_state")
local toc_render = require("markdown-plus.headers.toc_render")
local keymap_helper = require("markdown-plus.keymap_helper")

local M = {}

---Expand a header to show its children
---@return nil
function M.expand_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.state.visible_headers then
    return
  end

  local visible_header = toc_state.state.visible_headers[line]
  if not visible_header.has_children then
    return
  end

  -- Mark as expanded
  toc_state.state.expanded_levels[visible_header.idx] = true

  -- Re-render
  toc_render.render_toc()
end

---Collapse a header to hide its children, or jump to parent if already collapsed
---@return nil
function M.collapse_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.state.visible_headers then
    return
  end

  local visible_header = toc_state.state.visible_headers[line]

  -- If already collapsed or expanded, collapse it
  if visible_header.is_expanded then
    toc_state.state.expanded_levels[visible_header.idx] = false
    toc_render.render_toc()
    return
  end

  -- Otherwise, find parent and collapse it
  local header_idx = visible_header.idx
  local current_level = visible_header.header.level

  -- Find parent
  for i = header_idx - 1, 1, -1 do
    if toc_state.state.headers[i].level < current_level then
      -- Found parent, collapse it
      toc_state.state.expanded_levels[i] = false

      -- Find the parent's line in visible headers and move cursor there
      for j, vh in ipairs(toc_state.state.visible_headers) do
        if vh.idx == i then
          toc_render.render_toc()
          vim.api.nvim_win_set_cursor(0, { j, 0 })
          return
        end
      end

      toc_render.render_toc()
      return
    end
  end
end

---Jump to the header in the source buffer
---@return nil
function M.jump_to_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.state.visible_headers then
    return
  end

  local visible_header = toc_state.state.visible_headers[line]
  local header = visible_header.header

  -- Find the window containing the source buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == toc_state.state.source_bufnr then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { header.line_num, 0 })
      vim.cmd("normal! zz") -- Center the line
      return
    end
  end
end

local HELP_LINES = {
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

local HELP_WIDTH = 43

---Create a scratch buffer with help text
---@return number Buffer number
local function create_help_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP_LINES)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  return buf
end

---Open a centered floating window and set close keymaps
---@param buf number Buffer to display in the floating window
local function open_help_win(buf)
  local height = #HELP_LINES
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - HELP_WIDTH) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = HELP_WIDTH,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
  })

  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"

  local close_keys = { "<Esc>", "q", "?", "<CR>" }
  for _, key in ipairs(close_keys) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, nowait = true, desc = "Close help window" })
  end
end

---Show help popup for TOC window keybindings
---@return nil
function M.show_toc_help()
  local buf = create_help_buf()
  open_help_win(buf)
end

---Set up keymaps for the TOC buffer
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup_toc_keymaps(config)
  local toc_keymaps = {
    {
      plug = keymap_helper.plug_name("TocExpand"),
      fn = M.expand_header,
      modes = "n",
      default_key = "l",
      desc = "Expand header",
      force_default = true,
      default_opts = { buffer = toc_state.state.toc_bufnr, silent = true, nowait = true },
    },
    {
      plug = keymap_helper.plug_name("TocCollapse"),
      fn = M.collapse_header,
      modes = "n",
      default_key = "h",
      desc = "Collapse header",
      force_default = true,
      default_opts = { buffer = toc_state.state.toc_bufnr, silent = true, nowait = true },
    },
    {
      plug = keymap_helper.plug_name("TocJump"),
      fn = M.jump_to_header,
      modes = "n",
      default_key = "<CR>",
      desc = "Jump to header",
      force_default = true,
      default_opts = { buffer = toc_state.state.toc_bufnr, silent = true, nowait = true },
    },
    {
      plug = keymap_helper.plug_name("TocClose"),
      fn = function()
        vim.cmd("close")
      end,
      modes = "n",
      default_key = "q",
      desc = "Close TOC",
      force_default = true,
      default_opts = { buffer = toc_state.state.toc_bufnr, silent = true, nowait = true },
    },
    {
      plug = keymap_helper.plug_name("TocHelp"),
      fn = M.show_toc_help,
      modes = "n",
      default_key = "?",
      desc = "Show help",
      force_default = true,
      default_opts = { buffer = toc_state.state.toc_bufnr, silent = true, nowait = true },
    },
  }

  keymap_helper.setup_keymaps(config, toc_keymaps)
end

return M
