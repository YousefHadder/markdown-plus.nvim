---@module 'markdown-plus.table.keymaps'
---@brief [[
--- Keymap setup for table features
---
--- Provides <Plug> mappings and default keybindings for all table operations
---@brief ]]

local M = {}

local keymap_helper = require("markdown-plus.keymap_helper")

local plug_mappings_registered = false

---@param direction "left"|"right"|"up"|"down"
---@param fallback_key string
---@return fun()
local function insert_nav_with_fallback(direction, fallback_key)
  return function()
    local navigation = require("markdown-plus.table.navigation")
    local success = navigation["move_" .. direction]()
    if not success then
      local key = vim.api.nvim_replace_termcodes(fallback_key, true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end
  end
end

---@param prefix string
---@param include_insert_defaults boolean
---@return markdown-plus.KeymapDef[]
local function get_keymap_defs(prefix, include_insert_defaults)
  return {
    -- Table creation & formatting
    {
      plug = "markdown-plus-table-create",
      fn = function()
        require("markdown-plus.table.creator").create_table_interactive()
      end,
      modes = "n",
      default_key = prefix .. "c",
      desc = "Create new table",
    },
    {
      plug = "markdown-plus-table-format",
      fn = function()
        require("markdown-plus.table").format_table()
      end,
      modes = "n",
      default_key = prefix .. "f",
      desc = "Format table",
    },
    {
      plug = "markdown-plus-table-normalize",
      fn = function()
        require("markdown-plus.table").normalize_table()
      end,
      modes = "n",
      default_key = prefix .. "n",
      desc = "Normalize table",
    },

    -- Row operations
    {
      plug = "markdown-plus-table-insert-row-below",
      fn = function()
        require("markdown-plus.table").insert_row_below()
      end,
      modes = "n",
      default_key = prefix .. "ir",
      desc = "Insert row below",
    },
    {
      plug = "markdown-plus-table-insert-row-above",
      fn = function()
        require("markdown-plus.table").insert_row_above()
      end,
      modes = "n",
      default_key = prefix .. "iR",
      desc = "Insert row above",
    },
    {
      plug = "markdown-plus-table-delete-row",
      fn = function()
        require("markdown-plus.table").delete_row()
      end,
      modes = "n",
      default_key = prefix .. "dr",
      desc = "Delete row",
    },
    {
      plug = "markdown-plus-table-duplicate-row",
      fn = function()
        require("markdown-plus.table.manipulation").duplicate_row()
      end,
      modes = "n",
      default_key = prefix .. "yr",
      desc = "Duplicate row",
    },

    -- Column operations
    {
      plug = "markdown-plus-table-insert-column-right",
      fn = function()
        require("markdown-plus.table").insert_column_right()
      end,
      modes = "n",
      default_key = prefix .. "ic",
      desc = "Insert column right",
    },
    {
      plug = "markdown-plus-table-insert-column-left",
      fn = function()
        require("markdown-plus.table").insert_column_left()
      end,
      modes = "n",
      default_key = prefix .. "iC",
      desc = "Insert column left",
    },
    {
      plug = "markdown-plus-table-delete-column",
      fn = function()
        require("markdown-plus.table").delete_column()
      end,
      modes = "n",
      default_key = prefix .. "dc",
      desc = "Delete column",
    },
    {
      plug = "markdown-plus-table-duplicate-column",
      fn = function()
        require("markdown-plus.table.manipulation").duplicate_column()
      end,
      modes = "n",
      default_key = prefix .. "yc",
      desc = "Duplicate column",
    },

    -- Cell operations
    {
      plug = "markdown-plus-table-toggle-cell-alignment",
      fn = function()
        require("markdown-plus.table").toggle_cell_alignment()
      end,
      modes = "n",
      default_key = prefix .. "a",
      desc = "Toggle cell alignment (left/center/right)",
    },
    {
      plug = "markdown-plus-table-clear-cell",
      fn = function()
        require("markdown-plus.table").clear_cell()
      end,
      modes = "n",
      default_key = prefix .. "x",
      desc = "Clear cell content",
    },

    -- Row movement
    {
      plug = "markdown-plus-table-move-row-down",
      fn = function()
        require("markdown-plus.table").move_row_down()
      end,
      modes = "n",
      default_key = prefix .. "mj",
      desc = "Move row down",
    },
    {
      plug = "markdown-plus-table-move-row-up",
      fn = function()
        require("markdown-plus.table").move_row_up()
      end,
      modes = "n",
      default_key = prefix .. "mk",
      desc = "Move row up",
    },

    -- Column movement
    {
      plug = "markdown-plus-table-move-column-left",
      fn = function()
        require("markdown-plus.table").move_column_left()
      end,
      modes = "n",
      default_key = prefix .. "mh",
      desc = "Move column left",
    },
    {
      plug = "markdown-plus-table-move-column-right",
      fn = function()
        require("markdown-plus.table").move_column_right()
      end,
      modes = "n",
      default_key = prefix .. "ml",
      desc = "Move column right",
    },

    -- Advanced operations
    {
      plug = "markdown-plus-table-transpose",
      fn = function()
        require("markdown-plus.table").transpose_table()
      end,
      modes = "n",
      default_key = prefix .. "t",
      desc = "Transpose table (swap rows/columns)",
    },
    {
      plug = "markdown-plus-table-sort-ascending",
      fn = function()
        require("markdown-plus.table").sort_ascending()
      end,
      modes = "n",
      default_key = prefix .. "sa",
      desc = "Sort table by column (ascending)",
    },
    {
      plug = "markdown-plus-table-sort-descending",
      fn = function()
        require("markdown-plus.table").sort_descending()
      end,
      modes = "n",
      default_key = prefix .. "sd",
      desc = "Sort table by column (descending)",
    },
    {
      plug = "markdown-plus-table-to-csv",
      fn = function()
        require("markdown-plus.table").table_to_csv()
      end,
      modes = "n",
      default_key = prefix .. "vx",
      desc = "Convert table to CSV",
    },
    {
      plug = "markdown-plus-table-from-csv",
      fn = function()
        require("markdown-plus.table").csv_to_table()
      end,
      modes = "n",
      default_key = prefix .. "vi",
      desc = "Convert CSV to table",
    },

    -- Insert mode navigation (with fallback behavior)
    {
      plug = "markdown-plus-table-nav-left",
      fn = insert_nav_with_fallback("left", "<Left>"),
      modes = "i",
      default_key = include_insert_defaults and "<A-h>" or nil,
      desc = "Navigate to cell left or move cursor left",
    },
    {
      plug = "markdown-plus-table-nav-right",
      fn = insert_nav_with_fallback("right", "<Right>"),
      modes = "i",
      default_key = include_insert_defaults and "<A-l>" or nil,
      desc = "Navigate to cell right or move cursor right",
    },
    {
      plug = "markdown-plus-table-nav-up",
      fn = insert_nav_with_fallback("up", "<Up>"),
      modes = "i",
      default_key = include_insert_defaults and "<A-k>" or nil,
      desc = "Navigate to cell above or move cursor up",
    },
    {
      plug = "markdown-plus-table-nav-down",
      fn = insert_nav_with_fallback("down", "<Down>"),
      modes = "i",
      default_key = include_insert_defaults and "<A-j>" or nil,
      desc = "Navigate to cell below or move cursor down",
    },
  }
end

---Register global <Plug> mappings (should be called once)
local function register_plug_mappings()
  if plug_mappings_registered then
    return
  end

  plug_mappings_registered = true
  keymap_helper.setup_keymaps({ keymaps = { enabled = false } }, get_keymap_defs("<localleader>t", true))
end

---Setup buffer-local default keymaps
---@param config markdown-plus.InternalTableConfig Table configuration
local function setup_buffer_keymaps(config)
  register_plug_mappings()

  local prefix = config.keymaps.prefix or "<localleader>t"
  local insert_nav_enabled = config.keymaps.insert_mode_navigation
  if insert_nav_enabled == nil then
    insert_nav_enabled = true
  end

  keymap_helper.setup_keymaps({
    keymaps = {
      enabled = config.keymaps.enabled,
    },
  }, get_keymap_defs(prefix, insert_nav_enabled))
end

---Register global <Plug> mappings (call once during module setup)
function M.register_plug_mappings()
  register_plug_mappings()
end

---Setup buffer-local keymaps for current buffer
---@param config markdown-plus.InternalTableConfig Table configuration
function M.setup_buffer_keymaps(config)
  setup_buffer_keymaps(config)
end

---Setup table keymaps (registers <Plug> mappings once, then sets up buffer-local defaults)
---For backward compatibility - prefer calling register_plug_mappings() once and setup_buffer_keymaps() per buffer
---@param config markdown-plus.InternalTableConfig Table configuration
function M.setup(config)
  register_plug_mappings()
  setup_buffer_keymaps(config)
end

return M
