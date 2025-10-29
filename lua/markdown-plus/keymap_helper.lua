-- Keymap helper module for markdown-plus.nvim
-- Centralizes keymap setup logic to reduce duplication across feature modules
local M = {}

---Keymap definition
---@class markdown-plus.KeymapDef
---@field plug string The <Plug> mapping name (e.g., "MarkdownPlusBold")
---@field fn function|string The function to call or <Plug> name
---@field modes string|string[] Mode(s) for the keymap ('n', 'v', 'x', 'i')
---@field default_key? string|string[] Default key binding (optional, per mode if array)
---@field desc string Description for the keymap

---Setup keymaps for a module
---@param config markdown-plus.InternalConfig Plugin configuration
---@param keymaps markdown-plus.KeymapDef[] List of keymap definitions
---@return nil
function M.setup_keymaps(config, keymaps)
  if not config.keymaps or not config.keymaps.enabled then
    return
  end

  for _, keymap in ipairs(keymaps) do
    local modes = type(keymap.modes) == "table" and keymap.modes or { keymap.modes }
    local default_keys = keymap.default_key
    if default_keys and type(default_keys) ~= "table" then
      default_keys = { default_keys }
    end

    for idx, mode in ipairs(modes) do
      -- Create <Plug> mapping
      local plug_name = "<Plug>(" .. keymap.plug .. ")"
      local fn = keymap.fn

      -- If fn is a table, use the function for this mode index
      if type(fn) == "table" then
        fn = fn[idx]
      end

      vim.keymap.set(mode, plug_name, fn, {
        silent = true,
        desc = keymap.desc,
      })

      -- Set default keymap if not already mapped and default is specified
      if default_keys and default_keys[idx] and vim.fn.hasmapto(plug_name, mode) == 0 then
        vim.keymap.set(mode, default_keys[idx], plug_name, {
          buffer = true,
          desc = keymap.desc,
        })
      end
    end
  end
end

---Create a standard <Plug> mapping name
---@param feature string Feature name (e.g., "Bold", "NextHeader")
---@return string Full <Plug> name without <Plug>() wrapper
function M.plug_name(feature)
  return "MarkdownPlus" .. feature
end

return M
