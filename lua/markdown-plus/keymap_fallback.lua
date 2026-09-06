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

require("markdown-plus.keymap.types")
local guard = require("markdown-plus.keymap.guard")
local resolve = require("markdown-plus.keymap.resolve")
local feed = require("markdown-plus.keymap.feed")
local M = {}

-- Preserve the existing entry points for callers and teardown.
M.resolve = resolve.resolve
M.reset = guard.reset

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

---Run a Lua callback target
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side, used for error reporting and the raw-key fallback
---@param count? integer Normal-mode count to re-apply to the produced keys
---@param degrade? string Key to feed instead of `lhs` when degrading (`opts.fallback_key`)
---@return nil
local function run_callback(target, lhs, count, degrade)
  local ok, result = pcall(target.callback)
  if not ok then
    notify_failure(lhs, result)
    -- Deliberately countless: a target that threw partway may already have acted on the count,
    -- so re-prefixing it here risks doubling. Unlike the `feed_mapped` punt, which drops the
    -- count because prefixing is *unsafe*, this one drops it because it may be *already spent*.
    feed.raw(degrade or lhs)
    return
  end
  if target.expr then
    feed.expr_result(result, target, lhs, count, degrade)
  end
end

---Run a string-rhs target
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side, used for error reporting and the raw-key fallback
---@param count? integer Normal-mode count to re-apply to the produced keys
---@param degrade? string Key to feed instead of `lhs` when degrading (`opts.fallback_key`)
---@return nil
local function run_rhs(target, lhs, count, degrade)
  if target.expr then
    local ok, result = pcall(vim.api.nvim_eval, target.rhs)
    if not ok then
      notify_failure(lhs, result)
      -- Countless for the same reason as the callback error path above: possibly already spent.
      feed.raw(degrade or lhs)
      return
    end
    feed.expr_result(result, target, lhs, count, degrade)
    return
  end

  -- `from_part = false` here: an rhs is a full key sequence, unlike an lhs, where
  -- `normalize()` passes `from_part = true` to keep partial-key semantics for comparison.
  feed.target(vim.api.nvim_replace_termcodes(target.rhs, true, false, true), target, lhs, count, degrade)
end

---Execute the mapping markdown-plus is deferring to, or feed the raw key when there is none.
---The resolved target is executed directly — `lhs` is never re-fed through mapping
---resolution — so this can never recurse back into our own buffer-local default.
---
---Counts need help in two places. Targets are invoked synchronously from inside our own mapping,
---where `v:count` is still the one the user typed, so a callback or expression *reads* it fine —
---but the keys it produces are fed by us, outside that pending count, so the multiplier is lost
---unless re-applied. Vim's own behavior is a plain prefix (`2` + rhs `jj` moves two lines, it
---does not run `jj` twice), which is what `opts.count` reproduces on the noremap feed paths and
---on the raw-key degradation.
---
---Remappable targets are the known gap: see `keymap.feed.target`.
---
---Every path that terminates in a raw key honours `opts.fallback_key` when one is given, so a
---default whose lhs is inert on its own still ends in the behavior its handler documents.
---@param mode string Mapping mode ("i", "n", ...)
---@param lhs string Left-hand side (e.g. "<BS>")
---@param opts? markdown-plus.FallbackOpts Optional behavior overrides
---@return nil
function M.run(mode, lhs, opts)
  local degrade = opts and opts.fallback_key
  local count = opts and opts.count
  if guard.consume_bounce(mode, lhs) then
    -- Re-entered inside the same key-processing burst with nothing to show for the previous
    -- fallback: the target we deferred to routed the key straight back into us. Consume the
    -- guard so the chain ends here, and terminate with the raw key.
    --
    -- The count comes along: an unchanged changedtick says the target changed no buffer text,
    -- so a multiplier the user typed cannot have been spent as an edit — unlike the
    -- target-error path, where a target may have acted partway before throwing. The tick says
    -- nothing about non-textual work (a cursor move, a popup), which is accepted: a count
    -- applied to the raw key is the same thing vanilla Neovim does with an untouched buffer.
    feed.raw(degrade or lhs, count)
    return
  end

  local target = M.resolve(mode, lhs)

  if not target then
    feed.raw(degrade or lhs, count)
    return
  end

  guard.arm(mode, lhs)
  local ok, err = pcall(function()
    if target.callback then
      run_callback(target, lhs, count, degrade)
    elseif type(target.rhs) == "string" and target.rhs ~= "" then
      run_rhs(target, lhs, count, degrade)
    else
      -- Target with an empty rhs: nothing to run, so this is the raw-key path and still owns
      -- the count.
      feed.raw(degrade or lhs, count)
    end
  end)

  if not ok then
    notify_failure(lhs, err)
  end
end

return M
