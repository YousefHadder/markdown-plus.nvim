-- Recursion protection spanning a whole key-processing burst.
local M = {}

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
-- re-enter us in a later event-loop turn -- either because it is remappable and reproduces the
-- lhs (LuaSnip-style `<Tab>`), or because it feeds our own `<Plug>` into the typeahead behind
-- our back. copilot.lua's passthrough does exactly that: it captures the mapping we installed,
-- replaces it, and on passthrough feeds `<Plug>(MarkdownPlusListOutdent)` while returning
-- `<Ignore>`, so our handler runs again and resolves copilot again -- forever.
--
-- The guard is therefore released from a scheduled callback rather than at the end of run().
-- Scheduled callbacks only run once the typeahead is empty, so the guard spans the whole
-- key-processing burst -- including keys a target queued -- and is gone before the next
-- keypress.
--
-- Within a burst, a bounce is told apart from a genuine repeat press (macro replay, key
-- repeat) by the changedtick: a re-entry that follows a fallback which changed nothing is a
-- bounce and degrades to the raw key, while a re-entry after the buffer moved on is a new
-- press and gets a real fallback.
local in_flight = {}
local release_scheduled = false

---Identify a key's fallback in the current buffer.
---@param mode string
---@param lhs string
---@return string
local function guard_key(mode, lhs)
  return mode .. ":" .. vim.api.nvim_get_current_buf() .. ":" .. lhs
end

---Current buffer changedtick, or -1 when it cannot be read
---@return integer
local function buffer_tick()
  local ok, tick = pcall(vim.api.nvim_buf_get_changedtick, 0)
  return ok and tick or -1
end

---Consume a re-entry whose previous fallback left the buffer unchanged.
---@param mode string
---@param lhs string
---@return boolean
function M.consume_bounce(mode, lhs)
  local key = guard_key(mode, lhs)
  if in_flight[key] == buffer_tick() then
    in_flight[key] = nil
    return true
  end
  return false
end

---Mark a key's fallback as in flight and schedule the release sweep.
---@param mode string
---@param lhs string
---@return nil
function M.arm(mode, lhs)
  in_flight[guard_key(mode, lhs)] = buffer_tick()
  if release_scheduled then
    return
  end
  release_scheduled = true
  vim.schedule(function()
    release_scheduled = false
    in_flight = {}
  end)
end

---Clear all in-flight guards.
---Guards normally expire on their own once the typeahead drains; this exists for teardown
---(specs, `enable()`/`disable()` cycles) where no event-loop turn is guaranteed in between.
---@return nil
function M.reset()
  in_flight = {}
  -- Also clear the sweep flag so the next `arm()` schedules its own release instead of
  -- relying on a callback armed before the reset. A sweep left in flight is a harmless no-op:
  -- it only clears an already-empty (or freshly armed) table one event-loop turn later.
  release_scheduled = false
end

return M
