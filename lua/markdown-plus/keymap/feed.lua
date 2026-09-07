-- Replay resolved targets without routing fallback keys back through our defaults.
require("markdown-plus.keymap.types")
local normalize = require("markdown-plus.keymap.resolve").normalize
local M = {}

-- Our `<Plug>` prefix in both notations a target can hand back: the literal text, and the
-- internal byte form produced by nvim_replace_termcodes(). Resolved lazily because the byte
-- encoding of `<Plug>` (K_SPECIAL KS_EXTRA KE_PLUG) is not stable across Neovim versions.
local OUR_PLUG_LITERAL = "<Plug>(MarkdownPlus"
local our_plug_keys

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

---Feed keys to Neovim without re-entering markdown-plus mappings unexpectedly.
---Keys are inserted at the *front* of the typeahead ("i"), so the fallback completes before
---any keys the user has already typed behind the one being handled.
---
---Trade-off: front-insertion splices our keys ahead of anything the target itself queued --
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

---Feed a literal key as a last resort when no target could be run.
---
---`key` is normally the lhs itself, but callers pass `opts.fallback_key` instead when the lhs
---has no native meaning worth degrading to (see `markdown-plus.FallbackOpts`).
---
---A normal-mode count is consumed by *our* mapping, so feeding the bare key would drop it and
---turn `3o` into a single open-line. Re-prefixing the digits restores the native behavior.
---Only callers that know the count is still unspent pass one: on the error path a foreign target
---may already have acted on it, and re-applying would double it.
---@param key string Key to feed
---@param count? integer Normal-mode count to re-apply; ignored when nil or 1
---@return nil
function M.raw(key, count)
  local prefix = (count and count > 1) and tostring(count) or ""
  feed(prefix .. normalize(key), true)
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

---Feed the keys a resolved target produced, honouring its `noremap` flag.
---
---A pending count survives an expr mapping in vanilla Neovim and applies to the keys the
---mapping hands back (`3o` through a foreign expr `o` map opens three lines). Our own mapping
---consumes the count, so it is re-prefixed onto the produced keys. Digits are never remappable,
---so prefixing them cannot change how the rest of the sequence resolves.
---
---Known gap: the count is *not* applied on the remappable (`feed_mapped`) path. Digits break
---the leading-lhs comparison that keeps a target reproducing its own lhs from looping, and a
---remapped key after the digits could re-enter us. Remappable string-rhs `o`-style maps
---therefore lose the multiplier; no real plugin uses that shape.
---
---`degrade` shares that carve-out: `feed_mapped` protects a target whose rhs starts with its own
---lhs by feeding the literal `lhs`, never the substitute, because the substitute would not match
---the leading-lhs comparison the loop guard depends on. Vanilla Neovim feeds the lhs there too.
---@param keys string Key sequence with termcodes already expanded
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side the target was resolved for
---@param count? integer Normal-mode count to re-apply; ignored when nil or 1
---@param degrade? string Key to feed instead of `lhs` when degrading (`opts.fallback_key`)
---@return nil
function M.target(keys, target, lhs, count, degrade)
  if routes_back_to_us(keys) then
    -- The bounce replaces the target's execution entirely, so the raw key carries the count.
    M.raw(degrade or lhs, count)
    return
  end
  if target.noremap then
    local prefix = (count and count > 1) and tostring(count) or ""
    feed(prefix .. keys, true)
  else
    feed_mapped(keys, lhs)
  end
end

---Execute the keys produced by an expr mapping
---@param result any Value returned by the expr callback or expression
---@param target markdown-plus.FallbackTarget Resolved target
---@param lhs string Left-hand side the target was resolved for
---@param count? integer Normal-mode count to re-apply to the produced keys
---@param degrade? string Key to feed instead of `lhs` when degrading (`opts.fallback_key`)
---@return nil
function M.expr_result(result, target, lhs, count, degrade)
  if type(result) ~= "string" or result == "" then
    return
  end
  local keys = target.replace_keycodes and vim.api.nvim_replace_termcodes(result, true, true, true) or result
  M.target(keys, target, lhs, count, degrade)
end

return M
