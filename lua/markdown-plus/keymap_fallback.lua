-- Keymap fallback for markdown-plus.nvim
--
-- markdown-plus installs buffer-local default keymaps for keys other plugins commonly
-- own (`<BS>`, `<CR>`, `<Tab>`, ...). When a contextual handler decides "this is not my
-- context", it must yield back to whatever mapping would have run otherwise instead of
-- reimplementing the default behavior.
--
-- Resolution is lazy (performed on every keypress) so that plugins which map late —
-- lazy-loaded on `InsertEnter`, for example — are still found after our FileType
-- `enable()` has already run.

local M = {}

-- rhs of a mapping installed by this plugin; excluded from fallback resolution.
-- Kept in sync with the teardown predicate in init.lua's clear_plugin_default_keymaps().
local OUR_RHS_PATTERN = "^<Plug>%(MarkdownPlus[^)]+%)$"

-- Keys whose fallback is currently executing, keyed by "<mode>:<lhs>".
-- Excluding our `<Plug>` rhs is not sufficient on its own: a user (or a spec) may map a key
-- straight to a markdown-plus handler function, in which case the resolved target is our own
-- handler and invoking it would recurse. Re-entry therefore degrades to the raw key.
--
-- Scope: the guard covers the *synchronous* execution of a target only — it is released as
-- soon as run() returns. It does not protect against a foreign remappable (`noremap == 0`)
-- string rhs that expands to contain the same lhs, since those keys are consumed from the
-- typeahead after the guard is gone. That is not reachable with the plugins this exists for
-- (mini.pairs, nvim-cmp, blink.cmp all use expr or noremap mappings), and a depth counter
-- would not help either: the re-entry happens in a later event-loop turn, not on our stack.
local in_flight = {}

-- Memoized `normalize()` results. Keyed by the raw lhs string; the set of distinct keys in
-- play is tiny (our own defaults plus whatever the user has mapped), so this stays bounded.
local normalized_cache = {}

---A mapping that markdown-plus should defer to.
---@class markdown-plus.FallbackTarget
---@field callback? fun():any Lua mapping callback (preferred over `rhs` when present)
---@field rhs? string String right-hand side, termcodes unexpanded
---@field expr boolean Whether the mapping is an expression mapping
---@field noremap boolean Whether fed keys must bypass further mapping resolution
---@field replace_keycodes boolean Whether expr results need `nvim_replace_termcodes`

---Normalize a keymap left-hand side to its internal byte representation for comparison
---@param lhs string Left-hand side in any notation (e.g. "<BS>", "<F5>", "x")
---@return string Normalized key sequence
local function normalize(lhs)
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
  local wanted = normalize(lhs)
  for _, mapping in ipairs(mappings) do
    -- Exact compare first: keymap entries usually report the lhs in the same notation we
    -- were called with, so most iterations avoid normalizing at all.
    local candidate = mapping.lhs
    if type(candidate) == "string" and (candidate == lhs or normalize(candidate) == wanted) then
      if not is_ours(mapping) then
        return to_target(mapping)
      end
    end
  end
  return nil
end

---Feed keys to Neovim without re-entering markdown-plus mappings unexpectedly.
---Keys are inserted at the *front* of the typeahead ("i"), so the fallback completes before
---any keys the user has already typed behind the one being handled.
---
---Trade-off: front-insertion splices our keys ahead of anything the target itself queued —
---an expr callback that both returns keys *and* calls `nvim_feedkeys` would see the two
---interleaved in the wrong order. Accepted: a well-behaved expr mapping returns its keys
---rather than feeding them, and appending instead would reorder against real user input,
---which is the more common and more visible failure.
---@param keys string Key sequence with termcodes already expanded
---@param noremap boolean Whether to bypass mapping resolution for the fed keys
---@return nil
local function feed(keys, noremap)
  vim.api.nvim_feedkeys(keys, noremap and "ni" or "mi", false)
end

---Feed the literal `lhs` as a last resort when no target could be run
---@param lhs string Left-hand side to feed
---@return nil
local function feed_raw(lhs)
  feed(normalize(lhs), true)
end

---Report a fallback failure to the user
---@param lhs string Left-hand side whose fallback failed
---@param err any Error value from `pcall`
---@return nil
local function notify_failure(lhs, err)
  vim.notify(
    string.format("markdown-plus: fallback mapping for %s failed: %s", lhs, tostring(err)),
    vim.log.levels.ERROR
  )
end

---Resolve the current non-markdown-plus mapping for `(mode, lhs)` in the current buffer.
---Resolution order: buffer-local mapping that is not ours → global mapping → nil.
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

---Execute the keys produced by an expr mapping
---@param result any Value returned by the expr callback or expression
---@param target markdown-plus.FallbackTarget Resolved target
---@return nil
local function feed_expr_result(result, target)
  if type(result) ~= "string" or result == "" then
    return
  end
  local keys = target.replace_keycodes and vim.api.nvim_replace_termcodes(result, true, true, true) or result
  feed(keys, target.noremap)
end

---Run a Lua callback target
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side, used for error reporting and the raw-key fallback
---@return nil
local function run_callback(target, lhs)
  local ok, result = pcall(target.callback)
  if not ok then
    notify_failure(lhs, result)
    feed_raw(lhs)
    return
  end
  if target.expr then
    feed_expr_result(result, target)
  end
end

---Run a string-rhs target
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side, used for error reporting and the raw-key fallback
---@return nil
local function run_rhs(target, lhs)
  if target.expr then
    local ok, result = pcall(vim.api.nvim_eval, target.rhs)
    if not ok then
      notify_failure(lhs, result)
      feed_raw(lhs)
      return
    end
    feed_expr_result(result, target)
    return
  end

  -- `from_part = false` here: an rhs is a full key sequence, unlike an lhs, where
  -- `normalize()` passes `from_part = true` to keep partial-key semantics for comparison.
  feed(vim.api.nvim_replace_termcodes(target.rhs, true, false, true), target.noremap)
end

---Execute the mapping markdown-plus is deferring to, or feed the raw key when there is none.
---The resolved target is executed directly — `lhs` is never re-fed through mapping
---resolution — so this can never recurse back into our own buffer-local default.
---@param mode string Mapping mode ("i", "n", ...)
---@param lhs string Left-hand side (e.g. "<BS>")
---@return nil
function M.run(mode, lhs)
  local guard_key = mode .. ":" .. lhs
  if in_flight[guard_key] then
    feed_raw(lhs)
    return
  end

  local target = M.resolve(mode, lhs)

  if not target then
    feed_raw(lhs)
    return
  end

  in_flight[guard_key] = true
  local ok, err = pcall(function()
    if target.callback then
      run_callback(target, lhs)
    elseif type(target.rhs) == "string" and target.rhs ~= "" then
      run_rhs(target, lhs)
    else
      feed_raw(lhs)
    end
  end)
  in_flight[guard_key] = nil

  if not ok then
    notify_failure(lhs, err)
  end
end

return M
