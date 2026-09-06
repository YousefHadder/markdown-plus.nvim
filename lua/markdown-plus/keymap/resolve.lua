-- Resolve mappings on each keypress so late-installed foreign mappings are visible.
require("markdown-plus.keymap.types")
local M = {}

-- rhs of a mapping installed by this plugin; excluded from fallback resolution.
-- Kept in sync with the teardown predicate in init.lua's clear_plugin_default_keymaps().
local OUR_RHS_PATTERN = "^<Plug>%(MarkdownPlus[^)]+%)$"

-- Memoized `normalize()` results. Keyed by the raw lhs string; the set of distinct keys in
-- play is tiny (our own defaults plus whatever the user has mapped), so this stays bounded.
local normalized_cache = {}

---Normalize a keymap left-hand side to its internal byte representation for resolution and feeding.
---@param lhs string Left-hand side in any notation (e.g. "<BS>", "<F5>", "x")
---@return string Normalized key sequence
function M.normalize(lhs)
  local cached = normalized_cache[lhs]
  if cached == nil then
    cached = vim.api.nvim_replace_termcodes(lhs, true, true, true)
    normalized_cache[lhs] = cached
  end
  return cached
end

---Check whether a mapping was installed by markdown-plus
---@param mapping table Keymap entry from `nvim_get_keymap`/`nvim_buf_get_keymap`
---@return boolean
local function is_ours(mapping)
  return type(mapping.rhs) == "string" and mapping.rhs:match(OUR_RHS_PATTERN) ~= nil
end

---Convert a raw keymap entry into a fallback target
---@param mapping table Keymap entry from `nvim_get_keymap`/`nvim_buf_get_keymap`
---@return markdown-plus.FallbackTarget
local function to_target(mapping)
  return {
    callback = mapping.callback,
    rhs = mapping.rhs,
    expr = mapping.expr == 1,
    noremap = mapping.noremap == 1,
    replace_keycodes = mapping.replace_keycodes == 1,
  }
end

---Find the first foreign mapping for `lhs` in a list of keymap entries
---@param mappings table[] Keymap entries
---@param lhs string Left-hand side to match
---@return markdown-plus.FallbackTarget|nil
local function find_foreign(mappings, lhs)
  local wanted = M.normalize(lhs)
  for _, mapping in ipairs(mappings) do
    -- Exact compare first: keymap entries usually report the lhs in the same notation we
    -- were called with, so most iterations avoid normalizing at all.
    local candidate = mapping.lhs
    if type(candidate) == "string" and (candidate == lhs or M.normalize(candidate) == wanted) then
      if not is_ours(mapping) then
        return to_target(mapping)
      end
    end
  end
  return nil
end

---Resolve the current non-markdown-plus mapping for `(mode, lhs)` in the current buffer.
---Resolution order: buffer-local mapping that is not ours -> global mapping -> nil.
---@param mode string Mapping mode ("i", "n", ...)
---@param lhs string Left-hand side (e.g. "<BS>")
---@return markdown-plus.FallbackTarget|nil target Resolved target, or nil when none exists
function M.resolve(mode, lhs)
  local ok, buf_maps = pcall(vim.api.nvim_buf_get_keymap, 0, mode)
  if ok then
    local target = find_foreign(buf_maps, lhs)
    if target then
      return target
    end
  end

  local global_ok, global_maps = pcall(vim.api.nvim_get_keymap, mode)
  if global_ok then
    return find_foreign(global_maps, lhs)
  end

  return nil
end

return M
