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

-- Our `<Plug>` prefix in both notations a target can hand back: the literal text, and the
-- internal byte form produced by nvim_replace_termcodes(). Resolved lazily because the byte
-- encoding of `<Plug>` (K_SPECIAL KS_EXTRA KE_PLUG) is not stable across Neovim versions.
local OUR_PLUG_LITERAL = "<Plug>(MarkdownPlus"
local our_plug_keys

-- Keys whose fallback is currently executing, keyed by "<mode>:<buffer>:<lhs>" and holding the
-- buffer's changedtick at the moment the fallback was armed. The buffer number is part of the
-- key because the tick is read from the *current* buffer: a target that switches buffers would
-- otherwise be able to match another buffer's unrelated tick and look like a bounce.
--
-- Excluding our `<Plug>` rhs is not sufficient on its own: a user (or a spec) may map a key
-- straight to a markdown-plus handler function, in which case the resolved target is our own
-- handler and invoking it would recurse. Re-entry therefore degrades to the raw key.
--
-- Scope: the guard must outlive the *synchronous* execution of a target. A foreign target can
-- re-enter us in a later event-loop turn — either because it is remappable and reproduces the
-- lhs (LuaSnip-style `<Tab>`), or because it feeds our own `<Plug>` into the typeahead behind
-- our back. copilot.lua's passthrough does exactly that: it captures the mapping we installed,
-- replaces it, and on passthrough feeds `<Plug>(MarkdownPlusListOutdent)` while returning
-- `<Ignore>`, so our handler runs again and resolves copilot again — forever.
--
-- The guard is therefore released from a scheduled callback rather than at the end of run().
-- Scheduled callbacks only run once the typeahead is empty, so the guard spans the whole
-- key-processing burst — including keys a target queued — and is gone before the next
-- keypress.
--
-- Within a burst, a bounce is told apart from a genuine repeat press (macro replay, key
-- repeat) by the changedtick: a re-entry that follows a fallback which changed nothing is a
-- bounce and degrades to the raw key, while a re-entry after the buffer moved on is a new
-- press and gets a real fallback.
local in_flight = {}
local release_scheduled = false

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

---Check whether a key sequence would route back into a markdown-plus mapping.
---
---Completion plugins commonly *replace* our buffer-local default and keep the mapping they
---displaced as their own fallback (blink.cmp's `fallback` command, copilot.lua's passthrough).
---When such a target hands back the `<Plug>` it captured from us, feeding it re-enters the very
---handler that is already deferring to that target, and the two bounce off each other forever.
---markdown-plus has already decided it has nothing to do for this key in this context, so the
---correct terminal action is the raw key rather than another trip through our own mapping.
---@param keys string Key sequence, either literal notation or termcode-expanded
---@return boolean
local function routes_back_to_us(keys)
  if our_plug_keys == nil then
    our_plug_keys = vim.api.nvim_replace_termcodes(OUR_PLUG_LITERAL, true, true, true)
  end
  return keys:find(our_plug_keys, 1, true) ~= nil or keys:find(OUR_PLUG_LITERAL, 1, true) ~= nil
end

---Current buffer changedtick, or -1 when it cannot be read
---@return integer
local function buffer_tick()
  local ok, tick = pcall(vim.api.nvim_buf_get_changedtick, 0)
  return ok and tick or -1
end

---Mark a key's fallback as in flight and schedule the release sweep.
---@param guard_key string "<mode>:<buf>:<lhs>" guard key
---@return nil
local function arm_guard(guard_key)
  in_flight[guard_key] = buffer_tick()
  if release_scheduled then
    return
  end
  release_scheduled = true
  vim.schedule(function()
    release_scheduled = false
    in_flight = {}
  end)
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

---Feed keys produced by a *remappable* target, applying Vim's own recursion rule.
---`:help recursive_mapping` protects the first *character* of a rhs that starts with its own
---lhs; we protect the whole normalized lhs instead. That is stricter than Vim, and safe here
---because every lhs we install a fallback for is a single key. Without this, keys that
---reproduce the lhs would be resolved back through our buffer-local default and loop forever.
---@param keys string Key sequence with termcodes already expanded
---@param lhs string Left-hand side the target was resolved for
---@return nil
local function feed_mapped(keys, lhs)
  -- Only the *leading* occurrence is protected: a remappable target producing the lhs at a
  -- later position (rhs `<F5><F5>`) still loops, exactly as it does in vanilla Neovim with
  -- no markdown-plus involved. This matches Vim's semantics; it is not total loop immunity.
  local prefix = normalize(lhs)
  if prefix == "" or keys:sub(1, #prefix) ~= prefix then
    feed(keys, false)
    return
  end

  -- Both feeds insert at the *front* of the typeahead, so the last call ends up first.
  -- Feeding the remainder before the prefix therefore yields prefix-then-remainder order.
  local rest = keys:sub(#prefix + 1)
  if rest ~= "" then
    feed(rest, false)
  end
  feed(prefix, true)
end

---Feed the keys a resolved target produced, honouring its `noremap` flag
---@param keys string Key sequence with termcodes already expanded
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side the target was resolved for
---@return nil
local function feed_target(keys, target, lhs)
  if routes_back_to_us(keys) then
    feed_raw(lhs)
    return
  end
  if target.noremap then
    feed(keys, true)
  else
    feed_mapped(keys, lhs)
  end
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
---@param lhs string Left-hand side the target was resolved for
---@return nil
local function feed_expr_result(result, target, lhs)
  if type(result) ~= "string" or result == "" then
    return
  end
  local keys = target.replace_keycodes and vim.api.nvim_replace_termcodes(result, true, true, true) or result
  feed_target(keys, target, lhs)
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
    feed_expr_result(result, target, lhs)
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
    feed_expr_result(result, target, lhs)
    return
  end

  -- `from_part = false` here: an rhs is a full key sequence, unlike an lhs, where
  -- `normalize()` passes `from_part = true` to keep partial-key semantics for comparison.
  feed_target(vim.api.nvim_replace_termcodes(target.rhs, true, false, true), target, lhs)
end

---Execute the mapping markdown-plus is deferring to, or feed the raw key when there is none.
---The resolved target is executed directly — `lhs` is never re-fed through mapping
---resolution — so this can never recurse back into our own buffer-local default.
---@param mode string Mapping mode ("i", "n", ...)
---@param lhs string Left-hand side (e.g. "<BS>")
---@return nil
function M.run(mode, lhs)
  local guard_key = mode .. ":" .. vim.api.nvim_get_current_buf() .. ":" .. lhs
  if in_flight[guard_key] == buffer_tick() then
    -- Re-entered inside the same key-processing burst with nothing to show for the previous
    -- fallback: the target we deferred to routed the key straight back into us. Consume the
    -- guard so the chain ends here, and terminate with the raw key.
    in_flight[guard_key] = nil
    feed_raw(lhs)
    return
  end

  local target = M.resolve(mode, lhs)

  if not target then
    feed_raw(lhs)
    return
  end

  arm_guard(guard_key)
  local ok, err = pcall(function()
    if target.callback then
      run_callback(target, lhs)
    elseif type(target.rhs) == "string" and target.rhs ~= "" then
      run_rhs(target, lhs)
    else
      feed_raw(lhs)
    end
  end)

  if not ok then
    notify_failure(lhs, err)
  end
end

---Clear all in-flight guards.
---Guards normally expire on their own once the typeahead drains; this exists for teardown
---(specs, `enable()`/`disable()` cycles) where no event-loop turn is guaranteed in between.
---@return nil
function M.reset()
  in_flight = {}
  -- Also clear the sweep flag so the next `arm_guard()` schedules its own release instead of
  -- relying on a callback armed before the reset. A sweep left in flight is a harmless no-op:
  -- it only clears an already-empty (or freshly armed) table one event-loop turn later.
  release_scheduled = false
end

return M
