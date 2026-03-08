-- List management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")

-- Load sub-modules
local parser = require("markdown-plus.list.parser")
local handlers = require("markdown-plus.list.handlers")
local renumber = require("markdown-plus.list.renumber")
local checkbox = require("markdown-plus.list.checkbox")

local M = {}

local RENNUMBER_DEBOUNCE_MS = 150
local renumber_timers = {}
local ORDERED_LOOKAROUND = 20
local ORDERABLE_LIST_TYPES = {
  ordered = true,
  ordered_paren = true,
  letter_lower = true,
  letter_upper = true,
  letter_lower_paren = true,
  letter_upper_paren = true,
}

---@type markdown-plus.InternalConfig
M.config = {}

-- Re-export patterns for backwards compatibility
M.patterns = parser.patterns

---Setup list management module
---@param config markdown-plus.InternalConfig Plugin configuration
function M.setup(config)
  M.config = config or {}
  -- Pass list-specific config to checkbox module
  checkbox.setup(M.config.list)
  handlers.set_config(M.config)
  renumber.set_html_awareness(utils.is_html_awareness_enabled(M.config))
end

---Enable list features for current buffer
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for list management
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("ListEnter"),
      fn = handlers.skip_in_codeblock(handlers.handle_enter, "<CR>"),
      modes = "i",
      default_key = "<CR>",
      desc = "Auto-continue list or split content",
    },
    {
      plug = keymap_helper.plug_name("ListShiftEnter"),
      fn = handlers.skip_in_codeblock(handlers.continue_list_content, "<A-CR>"),
      modes = "i",
      default_key = "<A-CR>",
      desc = "Continue list content on next line",
    },
    {
      plug = keymap_helper.plug_name("ListIndent"),
      fn = handlers.skip_in_codeblock(handlers.handle_tab, "<Tab>"),
      modes = "i",
      default_key = "<Tab>",
      desc = "Indent list item",
    },
    {
      plug = keymap_helper.plug_name("ListOutdent"),
      fn = handlers.skip_in_codeblock(handlers.handle_shift_tab, "<S-Tab>"),
      modes = "i",
      default_key = "<S-Tab>",
      desc = "Outdent list item",
    },
    {
      plug = keymap_helper.plug_name("ListBackspace"),
      fn = handlers.skip_in_codeblock(handlers.handle_backspace, "<BS>"),
      modes = "i",
      default_key = "<BS>",
      desc = "Smart backspace (remove empty list)",
    },
    {
      plug = keymap_helper.plug_name("RenumberLists"),
      fn = renumber.renumber_ordered_lists,
      modes = "n",
      default_key = "<localleader>mr",
      desc = "Renumber ordered lists",
    },
    {
      plug = keymap_helper.plug_name("DebugLists"),
      fn = renumber.debug_list_groups,
      modes = "n",
      default_key = "<localleader>md",
      desc = "Debug list groups",
    },
    {
      plug = keymap_helper.plug_name("NewListItemBelow"),
      fn = handlers.skip_in_codeblock(handlers.handle_normal_o, "o"),
      modes = "n",
      default_key = "o",
      desc = "New list item below",
    },
    {
      plug = keymap_helper.plug_name("NewListItemAbove"),
      fn = handlers.skip_in_codeblock(handlers.handle_normal_O, "O"),
      modes = "n",
      default_key = "O",
      desc = "New list item above",
    },
    {
      plug = keymap_helper.plug_name("ToggleCheckbox"),
      fn = {
        checkbox.toggle_checkbox_line,
        checkbox.toggle_checkbox_range,
        checkbox.toggle_checkbox_insert,
      },
      modes = { "n", "x", "i" },
      default_key = { "<localleader>mx", "<localleader>mx", "<C-t>" },
      desc = "Toggle checkbox",
    },
  })

  -- Set up autocommands for auto-renumbering
  M.setup_renumber_autocmds()
end

---Set up autocommands for auto-renumbering
function M.setup_renumber_autocmds()
  local group = vim.api.nvim_create_augroup("MarkdownPlusListRenumber", { clear = true })

  local function get_cursor_row_for_buffer(bufnr)
    if vim.api.nvim_get_current_buf() == bufnr then
      return vim.api.nvim_win_get_cursor(0)[1]
    end

    local row = 1
    vim.api.nvim_buf_call(bufnr, function()
      row = vim.api.nvim_win_get_cursor(0)[1]
    end)
    return row
  end

  local function has_ordered_list_near_row(bufnr, row)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local start_row = math.max(1, row - ORDERED_LOOKAROUND)
    local end_row = math.min(line_count, row + ORDERED_LOOKAROUND)
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

    for idx, line in ipairs(lines) do
      local line_row = start_row + idx - 1
      local list_info = parser.parse_list_line(line, line_row)
      if list_info and ORDERABLE_LIST_TYPES[list_info.type] then
        return true
      end
    end

    return false
  end

  local function stop_debounce_timer(bufnr)
    local timer_id = renumber_timers[bufnr]
    if timer_id then
      pcall(vim.fn.timer_stop, timer_id)
      renumber_timers[bufnr] = nil
    end
  end

  -- Normal-mode edits: renumber immediately.
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    buffer = 0,
    callback = function(args)
      local bufnr = args.buf
      local cursor_row = get_cursor_row_for_buffer(bufnr)
      if not has_ordered_list_near_row(bufnr, cursor_row) then
        return
      end

      renumber.renumber_ordered_lists()
    end,
  })

  -- Insert-mode edits: debounce to avoid renumbering on every keystroke.
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = 0,
    callback = function(args)
      local bufnr = args.buf
      local cursor_row = get_cursor_row_for_buffer(bufnr)
      if not has_ordered_list_near_row(bufnr, cursor_row) then
        return
      end

      stop_debounce_timer(bufnr)

      renumber_timers[bufnr] = vim.fn.timer_start(RENNUMBER_DEBOUNCE_MS, function()
        renumber_timers[bufnr] = nil
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable then
            return
          end
          vim.api.nvim_buf_call(bufnr, function()
            renumber.renumber_ordered_lists()
          end)
        end)
      end)
    end,
  })

  -- Ensure timers are cleaned up for deleted buffers.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    buffer = 0,
    callback = function(args)
      stop_debounce_timer(args.buf)
    end,
  })
end

-- Re-export functions from sub-modules for backwards compatibility
M.parse_list_line = parser.parse_list_line
M.is_empty_list_item = parser.is_empty_list_item
M.break_out_of_list = handlers.break_out_of_list
M.index_to_letter = parser.index_to_letter
M.next_letter = parser.next_letter
M.create_next_list_item = handlers.create_next_list_item
M.handle_enter = handlers.handle_enter
M.continue_list_content = handlers.continue_list_content
M.handle_tab = handlers.handle_tab
M.handle_shift_tab = handlers.handle_shift_tab
M.handle_backspace = handlers.handle_backspace
M.handle_normal_o = handlers.handle_normal_o
M.handle_normal_O = handlers.handle_normal_O
M.renumber_ordered_lists = renumber.renumber_ordered_lists
M.find_list_groups = renumber.find_list_groups
M.is_list_breaking_line = renumber.is_list_breaking_line
M.renumber_list_group = renumber.renumber_list_group
M.debug_list_groups = renumber.debug_list_groups
M.toggle_checkbox_on_line = checkbox.toggle_checkbox_on_line
M.toggle_checkbox_in_line = checkbox.toggle_checkbox_in_line
M.replace_checkbox_state = checkbox.replace_checkbox_state
M.add_checkbox_to_line = checkbox.add_checkbox_to_line
M.toggle_checkbox_line = checkbox.toggle_checkbox_line
M.toggle_checkbox_range = checkbox.toggle_checkbox_range
M.toggle_checkbox_insert = checkbox.toggle_checkbox_insert
M.get_completion_config = checkbox.get_completion_config

return M
