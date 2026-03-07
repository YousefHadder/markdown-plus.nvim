--- Footnotes module for markdown-plus.nvim
--- Provides comprehensive footnote support: insert, edit, delete, navigate, and list
--- @module markdown-plus.footnotes

local parser = require("markdown-plus.footnotes.parser")
local insertion = require("markdown-plus.footnotes.insertion")
local navigation = require("markdown-plus.footnotes.navigation")
local window = require("markdown-plus.footnotes.window")
local keymap_helper = require("markdown-plus.keymap_helper")

local M = {}

--- @type markdown-plus.InternalConfig
M.config = {}

--- Default configuration for footnotes
--- @type markdown-plus.FootnotesConfig
M.default_config = {
  section_header = "Footnotes",
  confirm_delete = true,
}

--- Setup footnotes configuration
--- @param config markdown-plus.InternalConfig Plugin configuration
function M.setup(config)
  M.config = config or {}

  -- Get footnotes-specific config
  local footnotes_config = M.config.footnotes or {}
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), footnotes_config)

  -- Pass confirm_delete to insertion module
  insertion.set_confirm_delete(merged.confirm_delete)
  -- Pass section_header to insertion module
  insertion.set_section_header(merged.section_header)
end

--- Get current configuration
--- @return markdown-plus.FootnotesConfig
function M.get_config()
  return vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), M.config.footnotes or {})
end

--- Set up keymaps for footnotes functionality
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("FootnoteInsert"),
      fn = M.insert,
      modes = "n",
      default_key = "<leader>mfi",
      desc = "Insert footnote",
    },
    {
      plug = keymap_helper.plug_name("FootnoteEdit"),
      fn = M.edit,
      modes = "n",
      default_key = "<leader>mfe",
      desc = "Edit footnote",
    },
    {
      plug = keymap_helper.plug_name("FootnoteDelete"),
      fn = M.delete,
      modes = "n",
      default_key = "<leader>mfd",
      desc = "Delete footnote",
    },
    {
      plug = keymap_helper.plug_name("FootnoteGotoDefinition"),
      fn = M.goto_definition,
      modes = "n",
      default_key = "<leader>mfg",
      desc = "Go to footnote definition",
    },
    {
      plug = keymap_helper.plug_name("FootnoteGotoReference"),
      fn = M.goto_reference,
      modes = "n",
      default_key = "<leader>mfr",
      desc = "Go to footnote reference",
    },
    {
      plug = keymap_helper.plug_name("FootnoteNext"),
      fn = M.next_footnote,
      modes = "n",
      default_key = "<leader>mfn",
      desc = "Next footnote",
    },
    {
      plug = keymap_helper.plug_name("FootnotePrev"),
      fn = M.prev_footnote,
      modes = "n",
      default_key = "<leader>mfp",
      desc = "Previous footnote",
    },
    {
      plug = keymap_helper.plug_name("FootnoteList"),
      fn = M.list,
      modes = "n",
      default_key = "<leader>mfl",
      desc = "List footnotes",
    },
  })
end

--- Enable footnotes functionality for current buffer
---@return nil
function M.enable()
  M.setup_keymaps()
end

--- Disable footnotes functionality for a buffer
--- @param bufnr number Buffer number
function M.disable(bufnr)
  -- Close any open footnotes window for this buffer
  window.close_footnotes_window()
end

-- =============================================================================
-- Public API (delegate to sub-modules)
-- =============================================================================

--- Insert a new footnote at cursor position
--- Prompts for footnote ID with next numeric ID as default
function M.insert()
  insertion.insert_footnote()
end

--- Edit the footnote under cursor
--- Works for both references and definitions
function M.edit()
  insertion.edit_footnote()
end

--- Delete the footnote under cursor
--- Removes both reference and definition with confirmation
function M.delete()
  insertion.delete_footnote()
end

--- Jump from reference to definition
function M.goto_definition()
  navigation.goto_definition()
end

--- Jump from definition to reference(s)
--- If multiple references exist, prompts for selection
function M.goto_reference()
  navigation.goto_reference()
end

--- Navigate to the next footnote (reference or definition)
function M.next_footnote()
  navigation.next_footnote()
end

--- Navigate to the previous footnote (reference or definition)
function M.prev_footnote()
  navigation.prev_footnote()
end

--- Open the footnotes list picker
function M.list()
  window.open_footnotes_window()
end

-- =============================================================================
-- Parser API (expose for external use)
-- =============================================================================

--- Get all footnotes in the current buffer
--- @return markdown-plus.footnotes.Footnote[] Array of footnote information
function M.get_all_footnotes()
  return parser.get_all_footnotes()
end

--- Get the next available numeric ID
--- @return string Next numeric ID (e.g., "1", "2", etc.)
function M.get_next_id()
  return parser.get_next_numeric_id()
end

--- Find footnote reference or definition at cursor
--- @return {type: "reference"|"definition", id: string, line_num: number}|nil
function M.get_footnote_at_cursor()
  return parser.get_footnote_at_cursor()
end

return M
