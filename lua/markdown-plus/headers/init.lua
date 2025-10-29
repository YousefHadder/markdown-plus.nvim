-- Headers & TOC module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")

-- Load sub-modules
local parser = require("markdown-plus.headers.parser")
local navigation = require("markdown-plus.headers.navigation")
local manipulation = require("markdown-plus.headers.manipulation")
local toc = require("markdown-plus.headers.toc")
local toc_window = require("markdown-plus.headers.toc_window")

local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Header pattern (matches # through ######) - Re-export from parser
M.header_pattern = parser.header_pattern

---Setup headers module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
  
  -- Pass config to sub-modules that need it
  toc_window.set_config(M.config)
end

---Enable headers features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for headers
---@return nil
function M.setup_keymaps()
  local keymaps = {
    {
      plug = keymap_helper.plug_name("NextHeader"),
      fn = navigation.next_header,
      modes = "n",
      default_key = "]]",
      desc = "Jump to next header",
    },
    {
      plug = keymap_helper.plug_name("PrevHeader"),
      fn = navigation.prev_header,
      modes = "n",
      default_key = "[[",
      desc = "Jump to previous header",
    },
    {
      plug = keymap_helper.plug_name("PromoteHeader"),
      fn = manipulation.promote_header,
      modes = "n",
      default_key = "<leader>h+",
      desc = "Promote header (increase level)",
    },
    {
      plug = keymap_helper.plug_name("DemoteHeader"),
      fn = manipulation.demote_header,
      modes = "n",
      default_key = "<leader>h-",
      desc = "Demote header (decrease level)",
    },
    {
      plug = keymap_helper.plug_name("GenerateTOC"),
      fn = toc.generate_toc,
      modes = "n",
      default_key = "<leader>ht",
      desc = "Generate table of contents",
    },
    {
      plug = keymap_helper.plug_name("UpdateTOC"),
      fn = toc.update_toc,
      modes = "n",
      default_key = "<leader>hu",
      desc = "Update table of contents",
    },
    {
      plug = keymap_helper.plug_name("FollowLink"),
      fn = navigation.follow_link,
      modes = "n",
      default_key = "gd",
      desc = "Follow TOC link to header",
    },
    {
      plug = keymap_helper.plug_name("OpenTocWindow"),
      fn = function()
        toc_window.open_toc_window("vertical")
      end,
      modes = "n",
      default_key = "<leader>hT",
      desc = "Open navigable TOC window",
    },
  }

  -- Add header level shortcuts (h1-h6)
  for i = 1, 6 do
    table.insert(keymaps, {
      plug = keymap_helper.plug_name("Header" .. i),
      fn = function()
        manipulation.set_header_level(i)
      end,
      modes = "n",
      default_key = "<leader>h" .. i,
      desc = "Set/convert to H" .. i,
    })
  end

  keymap_helper.setup_keymaps(M.config, keymaps)

  -- User commands for TOC window
  vim.api.nvim_buf_create_user_command(0, "Toc", function()
    toc_window.open_toc_window("vertical")
  end, { desc = "Open TOC in vertical window" })

  vim.api.nvim_buf_create_user_command(0, "Toch", function()
    toc_window.open_toc_window("horizontal")
  end, { desc = "Open TOC in horizontal window" })

  vim.api.nvim_buf_create_user_command(0, "Toct", function()
    toc_window.open_toc_window("tab")
  end, { desc = "Open TOC in new tab" })
end

-- Re-export functions from sub-modules for backwards compatibility
M.parse_header = parser.parse_header
M.get_all_headers = parser.get_all_headers
M.generate_slug = parser.generate_slug
M.next_header = navigation.next_header
M.prev_header = navigation.prev_header
M.follow_link = navigation.follow_link
M.promote_header = manipulation.promote_header
M.demote_header = manipulation.demote_header
M.set_header_level = manipulation.set_header_level
M.generate_toc = toc.generate_toc
M.find_toc = toc.find_toc
M.update_toc = toc.update_toc
M.open_toc_window = toc_window.open_toc_window

return M
