-- Keymap helper module for markdown-plus.nvim
-- Centralizes keymap setup logic to reduce duplication across feature modules
local M = {}

-- Track which <Plug> mappings have been registered to avoid redundant global re-registration
local registered_plugs = {}
local DEFAULT_KEYMAPS_VAR = "markdown_plus_default_keymaps"

---@class markdown-plus.DefaultKeymapRecord
---@field mode string Keymap mode
---@field lhs string Default keymap left-hand side
---@field rhs string Default keymap right-hand side
---@field desc string Default keymap description

---Get default keymap records tracked on a buffer.
---@param bufnr integer Buffer handle
---@return markdown-plus.DefaultKeymapRecord[]
local function get_default_keymap_records(bufnr)
  local ok, records = pcall(vim.api.nvim_buf_get_var, bufnr, DEFAULT_KEYMAPS_VAR)
  if ok and type(records) == "table" then
    return records
  end
  return {}
end

---Remember a buffer-local default keymap so teardown does not depend on the visible description text.
---@param mode string Keymap mode
---@param lhs string Default keymap left-hand side
---@param rhs string Default keymap right-hand side
---@param desc string Default keymap description
---@return nil
local function track_default_keymap(mode, lhs, rhs, desc)
  local bufnr = vim.api.nvim_get_current_buf()
  local records = get_default_keymap_records(bufnr)
  table.insert(records, {
    mode = mode,
    lhs = lhs,
    rhs = rhs,
    desc = desc,
  })
  vim.api.nvim_buf_set_var(bufnr, DEFAULT_KEYMAPS_VAR, records)
end

---Keymap definition
---@class markdown-plus.KeymapDef
---@field plug string The <Plug> mapping name (e.g., "MarkdownPlusBold")
---@field fn function|string|function[] The function to call, <Plug> name, or array of functions per mode
---@field modes string|string[] Mode(s) for the keymap ('n', 'v', 'x', 'i')
---@field default_key? string|string[] Default key binding (optional). If both `modes` and `default_key` are arrays, they are indexed correspondingly (i.e., `modes[1]` gets `default_key[1]`, etc.).
---@field desc string Description for the keymap
---@field expr? boolean|boolean[] Whether the mapping is an expression mapping (optional). Can be a single boolean or array per mode.
---@field map_opts? table Additional options for the <Plug> mapping
---@field default_opts? table Additional options for the default keymap
---@field force_default? boolean Set default keymap even when config.keymaps.enabled is false

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
      local plug_name = "<Plug>(" .. keymap.plug .. ")"
      local plug_key = plug_name .. ":" .. mode

      -- Register <Plug> mapping once per mode (global, not buffer-local)
      if not registered_plugs[plug_key] then
        local fn = keymap.fn

        -- If fn is a table, use the function for this mode index
        if type(fn) == "table" then
          fn = fn[idx]
        end

        -- Determine if this mode uses expr mapping
        local is_expr = exprs and exprs[idx] or false

        local plug_opts = vim.tbl_extend("force", {
          silent = true,
          desc = keymap.desc,
          expr = is_expr,
        }, keymap.map_opts or {})

        vim.keymap.set(mode, plug_name, fn, plug_opts)
        registered_plugs[plug_key] = true
      end

      local should_set_default = config.keymaps and config.keymaps.enabled
      if keymap.force_default then
        should_set_default = true
      end

      -- Set default keymap only if enabled and default is specified
      if should_set_default and default_keys and default_keys[idx] then
        -- Check if a buffer-local mapping already exists for this key
        local existing = vim.fn.maparg(default_keys[idx], mode, false, true)
        local has_buffer_mapping = type(existing) == "table" and existing.buffer == 1

        if not has_buffer_mapping then
          local default_opts = vim.tbl_extend("force", {
            buffer = true,
            desc = keymap.desc,
          }, keymap.default_opts or {})

          vim.keymap.set(mode, default_keys[idx], plug_name, default_opts)
          track_default_keymap(mode, default_keys[idx], plug_name, default_opts.desc)
        end
      end
    end
  end
end

---Clear buffer-local default keymaps created through this helper.
---User mappings to <Plug>(MarkdownPlus...) targets are preserved because only tracked defaults are removed.
---@return nil
function M.clear_default_keymaps()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local records = get_default_keymap_records(bufnr)
      if #records > 0 then
        vim.api.nvim_buf_call(bufnr, function()
          for _, record in ipairs(records) do
            if type(record.lhs) == "string" and type(record.mode) == "string" then
              local existing = vim.fn.maparg(record.lhs, record.mode, false, true)
              local is_same_default = type(existing) == "table"
                and next(existing) ~= nil
                and existing.buffer == 1
                and existing.rhs == record.rhs
                and existing.desc == record.desc
              if is_same_default then
                pcall(vim.keymap.del, record.mode, record.lhs, { buffer = bufnr })
              end
            end
          end
        end)
        pcall(vim.api.nvim_buf_del_var, bufnr, DEFAULT_KEYMAPS_VAR)
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
