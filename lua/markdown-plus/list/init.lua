-- List management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")

-- Load sub-modules
local parser = require("markdown-plus.list.parser")
local handlers = require("markdown-plus.list.handlers")
local renumber = require("markdown-plus.list.renumber")
local checkbox = require("markdown-plus.list.checkbox")

local M = {}

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
      default_key = "<leader>mr",
      desc = "Renumber ordered lists",
    },
    {
      plug = keymap_helper.plug_name("DebugLists"),
      fn = renumber.debug_list_groups,
      modes = "n",
      default_key = "<leader>md",
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
      default_key = { "<leader>mx", "<leader>mx", "<C-t>" },
      desc = "Toggle checkbox",
    },
  })

  -- Set up autocommands for auto-renumbering
  M.setup_renumber_autocmds()
end

---Set up autocommands for auto-renumbering
function M.setup_renumber_autocmds()
  local group = vim.api.nvim_create_augroup("MarkdownPlusListRenumber", { clear = true })

  -- Renumber on text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = 0,
    callback = function()
      renumber.renumber_ordered_lists()
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
