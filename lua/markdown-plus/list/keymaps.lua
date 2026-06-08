-- List management keymaps for markdown-plus.nvim
-- Registers <Plug> mappings and buffer-local defaults for list editing, renumber,
-- new-item creation, checkbox toggling, and list-type toggling.
local keymap_helper = require("markdown-plus.keymap_helper")
local handlers = require("markdown-plus.list.handlers")
local renumber = require("markdown-plus.list.renumber")
local checkbox = require("markdown-plus.list.checkbox")
local toggle = require("markdown-plus.list.toggle")

local M = {}

---Register list-management keymaps for the current buffer.
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup_keymaps(config)
  keymap_helper.setup_keymaps(config, {
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
    {
      plug = keymap_helper.plug_name("ToggleListUnordered"),
      fn = {
        function()
          toggle.toggle_list_line("unordered")
        end,
        function()
          toggle.toggle_list_range("unordered")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltu", "<localleader>ltu" },
      desc = "Toggle unordered list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListOrdered"),
      fn = {
        function()
          toggle.toggle_list_line("ordered")
        end,
        function()
          toggle.toggle_list_range("ordered")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltn", "<localleader>ltn" },
      desc = "Toggle ordered list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListTask"),
      fn = {
        function()
          toggle.toggle_list_line("task")
        end,
        function()
          toggle.toggle_list_range("task")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltt", "<localleader>ltt" },
      desc = "Toggle task list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListPick"),
      fn = {
        toggle.toggle_list_pick_line,
        toggle.toggle_list_pick_range,
      },
      modes = { "n", "x" },
      desc = "Toggle list (pick type: u/t/n/N/l/L/p/P, c=clear)",
    },
    {
      plug = keymap_helper.plug_name("ToggleListOrderedParen"),
      fn = {
        function()
          toggle.toggle_list_line("ordered_paren")
        end,
        function()
          toggle.toggle_list_range("ordered_paren")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltN", "<localleader>ltN" },
      desc = "Toggle parenthesized ordered list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListLetterLower"),
      fn = {
        function()
          toggle.toggle_list_line("letter_lower")
        end,
        function()
          toggle.toggle_list_range("letter_lower")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltl", "<localleader>ltl" },
      desc = "Toggle lowercase letter list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListLetterUpper"),
      fn = {
        function()
          toggle.toggle_list_line("letter_upper")
        end,
        function()
          toggle.toggle_list_range("letter_upper")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltL", "<localleader>ltL" },
      desc = "Toggle uppercase letter list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListLetterLowerParen"),
      fn = {
        function()
          toggle.toggle_list_line("letter_lower_paren")
        end,
        function()
          toggle.toggle_list_range("letter_lower_paren")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltp", "<localleader>ltp" },
      desc = "Toggle parenthesized lowercase letter list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListLetterUpperParen"),
      fn = {
        function()
          toggle.toggle_list_line("letter_upper_paren")
        end,
        function()
          toggle.toggle_list_range("letter_upper_paren")
        end,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltP", "<localleader>ltP" },
      desc = "Toggle parenthesized uppercase letter list",
    },
    {
      plug = keymap_helper.plug_name("ToggleListClear"),
      fn = {
        toggle.clear_list_line,
        toggle.clear_list_range,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>ltc", "<localleader>ltc" },
      desc = "Clear list markers (plain text)",
    },
  })
end

return M
