-- Keymap helper module for markdown-plus.nvim
-- Centralizes keymap setup logic to reduce duplication across feature modules
local M = {}

---Keymap definition
---@class markdown-plus.KeymapDef
---@field plug string The <Plug> mapping name (e.g., "MarkdownPlusBold")
---@field fn function|string|function[] The function to call, <Plug> name, or array of functions per mode
---@field modes string|string[] Mode(s) for the keymap ('n', 'v', 'x', 'i')
---@field default_key? string|string[] Default key binding (optional). If both `modes` and `default_key` are arrays, they are indexed correspondingly (i.e., `modes[1]` gets `default_key[1]`, etc.).
---@field desc string Description for the keymap
---@field expr? boolean|boolean[] Whether the mapping is an expression mapping (optional). Can be a single boolean or array per mode.

---Setup keymaps for a module
---@param config markdown-plus.InternalConfig Plugin configuration
---@param keymaps markdown-plus.KeymapDef[] List of keymap definitions
---@return nil
function M.setup_keymaps(config, keymaps)
  for _, keymap in ipairs(keymaps) do
    local modes = type(keymap.modes) == "table" and keymap.modes or { keymap.modes }
    local default_keys = keymap.default_key
    if default_keys and type(default_keys) ~= "table" then
      default_keys = { default_keys }
    end
    local exprs = keymap.expr
    if exprs and type(exprs) ~= "table" then
      exprs = { exprs }
    end

    for idx, mode in ipairs(modes) do
      -- Always create <Plug> mapping (regardless of keymaps.enabled)
      local plug_name = "<Plug>(" .. keymap.plug .. ")"
      local fn = keymap.fn

      -- If fn is a table, use the function for this mode index
      if type(fn) == "table" then
        fn = fn[idx]
      end

      -- Determine if this mode uses expr mapping
      local is_expr = exprs and exprs[idx] or false

      vim.keymap.set(mode, plug_name, fn, {
        silent = true,
        desc = keymap.desc,
        expr = is_expr,
      })

      -- Set default keymap only if keymaps are enabled and default is specified
      if config.keymaps and config.keymaps.enabled and default_keys and default_keys[idx] then
        -- Check if a buffer-local mapping already exists for this key
        local existing = vim.fn.maparg(default_keys[idx], mode, false, true)
        local has_buffer_mapping = existing and existing.buffer == 1

        if not has_buffer_mapping then
          vim.keymap.set(mode, default_keys[idx], plug_name, {
            buffer = true,
            desc = keymap.desc,
          })
        end
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
