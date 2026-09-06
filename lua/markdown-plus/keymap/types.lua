---@meta
local M = {}

---A mapping that markdown-plus should defer to.
---@class markdown-plus.FallbackTarget
---@field callback? fun():any Lua mapping callback (preferred over `rhs` when present)
---@field rhs? string String right-hand side, termcodes unexpanded
---@field expr boolean Whether the mapping is an expression mapping
---@field noremap boolean Whether fed keys must bypass further mapping resolution
---@field replace_keycodes boolean Whether expr results need `nvim_replace_termcodes`

---Optional behavior overrides for `keymap_fallback.run`.
---@class markdown-plus.FallbackOpts
---@field count? integer Normal-mode count (`v:count1`) to re-apply to the keys the fallback
---feeds -- the resolved target's own keys, or the raw key when it degrades. Pass only from
---normal-mode handlers that have not acted on the count themselves.
---@field fallback_key? string Key to feed instead of `lhs` on every degradation path (no
---target, bounce, target error). For defaults that sit on a key with no native meaning of its
---own -- table navigation's `<A-l>` is inert in insert mode -- degrading to the literal lhs
---would swallow the press; naming the key the handler documents as its no-context behavior
---(`<Right>`) keeps it. Resolution and the recursion rule still use `lhs`.

return M
