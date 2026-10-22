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
local TOC_BUFFER_COMMANDS = { "Toc", "Toch", "Toct" }

---@class markdown-plus.OwnedTocCommand
---@field metadata table
---@field callback_fingerprint string|nil

---@type table<integer, table<string, markdown-plus.OwnedTocCommand>>
local owned_toc_commands = {}
---@type table<integer, integer>
local owned_toc_cleanup_autocmds = {}

---@type markdown-plus.InternalConfig
M.config = {}

---@param bufnr number
---@param command string
---@return string|nil
local function get_command_callback_fingerprint(bufnr, command)
  -- Neovim 0.11 omits Lua callbacks from nvim_buf_get_commands().
  local output = vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.execute("verbose command " .. command)
  end)

  for line in output:gmatch("[^\n]+") do
    local callback = line:match("^b%s+" .. command .. "%s.-(<Lua [^>]+>)")
    if callback then
      return callback
    end
  end
end

---@param bufnr number
---@param command string
---@param current table Current user-command metadata
---@param registered markdown-plus.OwnedTocCommand
---@return boolean
local function is_owned_toc_command(bufnr, command, current, registered)
  if not vim.deep_equal(current, registered.metadata) then
    return false
  end
  if current.callback ~= nil or registered.metadata.callback ~= nil then
    return current.callback ~= nil and current.callback == registered.metadata.callback
  end

  return registered.callback_fingerprint ~= nil
    and get_command_callback_fingerprint(bufnr, command) == registered.callback_fingerprint
end

---@param bufnr number
---@param command string
---@param callback function
---@param description string
---@return nil
local function create_toc_command(bufnr, command, callback, description)
  local commands = vim.api.nvim_buf_get_commands(bufnr, {})
  if commands[command] then
    return
  end

  vim.api.nvim_buf_create_user_command(bufnr, command, callback, { desc = description })

  local registered = vim.api.nvim_buf_get_commands(bufnr, {})[command]
  if registered then
    owned_toc_commands[bufnr] = owned_toc_commands[bufnr] or {}
    owned_toc_commands[bufnr][command] = {
      metadata = registered,
      callback_fingerprint = get_command_callback_fingerprint(bufnr, command),
    }

    if not owned_toc_cleanup_autocmds[bufnr] then
      owned_toc_cleanup_autocmds[bufnr] = vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = bufnr,
        once = true,
        callback = function()
          owned_toc_commands[bufnr] = nil
          owned_toc_cleanup_autocmds[bufnr] = nil
        end,
      })
    end
  end
end

---Header pattern (matches # through ######) - Re-export from parser
M.header_pattern = parser.header_pattern

---Setup headers module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
  -- Pass config to sub-modules that need it
  parser.set_html_awareness(utils.is_html_awareness_enabled(M.config))
  toc.set_config(M.config)
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
      default_key = "<localleader>h+",
      desc = "Promote header (increase level)",
    },
    {
      plug = keymap_helper.plug_name("DemoteHeader"),
      fn = manipulation.demote_header,
      modes = "n",
      default_key = "<localleader>h-",
      desc = "Demote header (decrease level)",
    },
    {
      plug = keymap_helper.plug_name("ToggleAtxSetext"),
      fn = manipulation.toggle_atx_setext,
      modes = "n",
      default_key = "<localleader>ms",
      desc = "Toggle heading between ATX and setext style",
    },
    {
      plug = keymap_helper.plug_name("GenerateTOC"),
      fn = toc.generate_toc,
      modes = "n",
      default_key = "<localleader>ht",
      desc = "Generate table of contents",
    },
    {
      plug = keymap_helper.plug_name("UpdateTOC"),
      fn = toc.update_toc,
      modes = "n",
      default_key = "<localleader>hu",
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
      default_key = "<localleader>hT",
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
      default_key = "<localleader>h" .. i,
      desc = "Set/convert to H" .. i,
    })
  end

  keymap_helper.setup_keymaps(M.config, keymaps)

  local bufnr = vim.api.nvim_get_current_buf()

  -- User commands for TOC window
  create_toc_command(bufnr, "Toc", function()
    toc_window.open_toc_window("vertical")
  end, "Open TOC in vertical window")
  create_toc_command(bufnr, "Toch", function()
    toc_window.open_toc_window("horizontal")
  end, "Open TOC in horizontal window")
  create_toc_command(bufnr, "Toct", function()
    toc_window.open_toc_window("tab")
  end, "Open TOC in new tab")
end

---@param bufnr number
---@return nil
function M.disable(bufnr)
  if not bufnr then
    return
  end
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local commands = vim.api.nvim_buf_get_commands(bufnr, {})
  local owned_commands = owned_toc_commands[bufnr]
  for _, command in ipairs(TOC_BUFFER_COMMANDS) do
    local registered = owned_commands and owned_commands[command]
    if commands[command] and registered and is_owned_toc_command(bufnr, command, commands[command], registered) then
      vim.api.nvim_buf_del_user_command(bufnr, command)
    end
  end
  owned_toc_commands[bufnr] = nil

  local cleanup_autocmd = owned_toc_cleanup_autocmds[bufnr]
  owned_toc_cleanup_autocmds[bufnr] = nil
  if cleanup_autocmd then
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ buffer = bufnr, event = "BufWipeout" })) do
      if autocmd.id == cleanup_autocmd then
        vim.api.nvim_del_autocmd(cleanup_autocmd)
        break
      end
    end
  end
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
M.toggle_atx_setext = manipulation.toggle_atx_setext
M.generate_toc = toc.generate_toc
M.find_toc = toc.find_toc
M.update_toc = toc.update_toc
M.open_toc_window = toc_window.open_toc_window

return M
