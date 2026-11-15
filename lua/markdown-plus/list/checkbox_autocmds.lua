-- Checkbox sync after edits for markdown-plus.nvim
-- With `list.checkbox_sync`, any edit that moves list items in the tree (indent, outdent, new,
-- deleted, moved or pasted items) or rewrites a checkbox by hand keeps parents and children in
-- sync, like the toggle does. A buffer attachment records exactly which lines each edit touched
-- and what they looked like before; the edits are synced once the change is complete.
local checkbox = require("markdown-plus.list.checkbox")
local checkbox_sync = require("markdown-plus.list.checkbox_sync")

local M = {}

local SYNC_DEBOUNCE_MS = 150
local AUGROUP_PREFIX = "MarkdownPlusCheckboxSync_"

---Lines touched since the last sync: the line's `line_key` from before the first edit, or `true`
---for a line that was inserted or sits right above inserted or deleted lines.
---@alias markdown-plus.list.CheckboxEdits table<integer, string|true>

---@class markdown-plus.list.CheckboxTracker
---@field keys string[] `checkbox_sync.line_key` of every line
---@field edits markdown-plus.list.CheckboxEdits Keyed by 1-indexed row
---@field seq_cur integer Undo state at the last sync
---@field seq_last integer Newest undo state at the last sync

---@type table<integer, markdown-plus.list.CheckboxTracker>
local trackers = {}

---Per-buffer insert-mode debounce timers.
---@type table<integer, integer>
local timers = {}

---@param bufnr integer Buffer number (0 for current)
---@return integer
local function resolve(bufnr)
  return bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
end

---@param bufnr integer
---@return nil
local function stop_timer(bufnr)
  local timer_id = timers[bufnr]
  if timer_id then
    pcall(vim.fn.timer_stop, timer_id)
    timers[bufnr] = nil
  end
end

---@param bufnr integer
---@param first integer 0-indexed first line
---@param last integer 0-indexed end line (exclusive)
---@return string[]
local function read_keys(bufnr, first, last)
  return vim.tbl_map(checkbox_sync.line_key, vim.api.nvim_buf_get_lines(bufnr, first, last, false))
end

---@param bufnr integer
---@return table
local function undotree(bufnr)
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.undotree()
  end)
end

---Shift the entries after a replaced range of a sparse or dense list.
---@param list table
---@param length integer Length of the list before the edit
---@param first integer 0-indexed first replaced line
---@param old_count integer
---@param new_count integer
---@return nil
local function shift(list, length, first, old_count, new_count)
  local delta = new_count - old_count
  if delta > 0 then
    for i = length, first + old_count + 1, -1 do
      list[i + delta] = list[i]
    end
  elseif delta < 0 then
    for i = first + old_count + 1, length do
      list[i + delta] = list[i]
    end
    for i = length + delta + 1, length do
      list[i] = nil
    end
  end
  for i = first + 1, first + new_count do
    list[i] = nil
  end
end

---Record an edit reported by `nvim_buf_attach`.
---@param tracker markdown-plus.list.CheckboxTracker
---@param bufnr integer
---@param first integer 0-indexed first changed line
---@param last_old integer 0-indexed end of the replaced lines (exclusive)
---@param last_new integer 0-indexed end of the new lines (exclusive)
---@return nil
local function record(tracker, bufnr, first, last_old, last_new)
  local old_count, new_count = last_old - first, last_new - first
  local length = #tracker.keys
  local new_keys = read_keys(bufnr, first, last_new)

  if old_count == new_count then
    for i = 1, new_count do
      local row = first + i
      if tracker.edits[row] == nil and tracker.keys[row] ~= new_keys[i] then
        tracker.edits[row] = tracker.keys[row]
      end
      tracker.keys[row] = new_keys[i]
    end
    return
  end

  shift(tracker.keys, length, first, old_count, new_count)
  shift(tracker.edits, length, first, old_count, new_count)
  for i = 1, new_count do
    tracker.keys[first + i] = new_keys[i]
    tracker.edits[first + i] = true
  end
  -- The item above may have lost or gained children
  if first > 0 then
    tracker.edits[first] = true
  end
end

---Forget recorded edits: the buffer is in sync as it is.
---@param bufnr integer
---@return nil
local function mark_synced(bufnr)
  local tracker = trackers[bufnr]
  if tracker then
    local tree = undotree(bufnr)
    tracker.edits = {}
    tracker.seq_cur, tracker.seq_last = tree.seq_cur, tree.seq_last
  end
end

---Start tracking a buffer's edits.
---@param bufnr integer
---@return nil
local function attach(bufnr)
  ---@type markdown-plus.list.CheckboxTracker
  local tracker = { keys = read_keys(bufnr, 0, -1), edits = {}, seq_cur = 0, seq_last = 0 }
  trackers[bufnr] = tracker
  mark_synced(bufnr)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, first, last_old, last_new)
      -- Returning true detaches: the buffer was disabled or re-attached since
      if trackers[buf] ~= tracker then
        return true
      end
      record(tracker, buf, first, last_old, last_new)
    end,
    on_reload = function(_, buf)
      if trackers[buf] == tracker then
        tracker.keys = read_keys(buf, 0, -1)
        mark_synced(buf)
      end
    end,
    on_detach = function(_, buf)
      if trackers[buf] == tracker then
        trackers[buf] = nil
      end
    end,
  })
end

---Whether the buffer reached its current undo state through a new edit.
---
---Undo and redo move between states that already exist and must not sync: the restored text is
---what the user asked for, and writing to it would create a new undo state on top of it, so `u`
---would undo the sync instead of moving further back.
---@param tracker markdown-plus.list.CheckboxTracker
---@param tree table `undotree()` result
---@return boolean
local function is_new_edit(tracker, tree)
  if tree.seq_last > tracker.seq_last then
    return true
  end
  -- An undo block that grew since the last sync, e.g. further typing in the same insert
  return tree.seq_cur == tracker.seq_cur and tree.seq_cur == tree.seq_last
end

---Take the sync changes recorded for a buffer since its last sync, and forget them.
---Edits restored by undo or redo yield no changes.
---@param bufnr integer Buffer number (0 for current)
---@return markdown-plus.list.CheckboxChange[]
function M.take_changes(bufnr)
  bufnr = resolve(bufnr)
  local tracker = trackers[bufnr]
  if not tracker or next(tracker.edits) == nil then
    return {}
  end

  local changes = {}
  if is_new_edit(tracker, undotree(bufnr)) then
    for row, old_key in pairs(tracker.edits) do
      local key = tracker.keys[row]
      local change = key and (old_key == true and { structural = true } or checkbox_sync.classify_edit(old_key, key))
      if change then
        change.row = row
        table.insert(changes, change)
        if change.structural and row > 1 then
          -- The item above may have been this item's old parent
          table.insert(changes, { row = row - 1, structural = true })
        end
      end
    end
    table.sort(changes, function(a, b)
      return a.row < b.row
    end)
  end
  tracker.edits = {}
  return changes
end

---Mark the buffer as in sync, so the edits made so far are not synced again.
---@param bufnr integer Buffer number (0 for current)
---@return nil
function M.refresh(bufnr)
  mark_synced(resolve(bufnr))
end

---Sync the checkboxes around the edits made since the last sync.
---@param bufnr integer Buffer number (0 for current)
---@return nil
function M.sync(bufnr)
  bufnr = resolve(bufnr)
  stop_timer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not checkbox.is_sync_enabled() then
    trackers[bufnr] = nil
    return
  end
  if not trackers[bufnr] then
    -- Re-enabled at runtime: start from the current text
    attach(bufnr)
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    local changes = M.take_changes(bufnr)
    if #changes > 0 and vim.bo.modifiable then
      -- Marks the buffer as synced once the updates are written
      checkbox.sync_checkboxes(changes, { undojoin = true })
    else
      mark_synced(bufnr)
    end
  end)
end

---Watch the current buffer's edits for checkbox sync, when `list.checkbox_sync` is enabled.
---@return nil
function M.setup()
  local bufnr = vim.api.nvim_get_current_buf()
  if not checkbox.is_sync_enabled() then
    M.disable(bufnr)
    return
  end
  stop_timer(bufnr)
  local group = vim.api.nvim_create_augroup(AUGROUP_PREFIX .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      M.sync(args.buf)
    end,
  })

  -- Insert-mode edits: wait for a pause in typing instead of syncing on every keystroke
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      local changed_bufnr = args.buf
      stop_timer(changed_bufnr)
      if not trackers[changed_bufnr] then
        return
      end
      local changedtick = vim.api.nvim_buf_get_changedtick(changed_bufnr)
      timers[changed_bufnr] = vim.fn.timer_start(SYNC_DEBOUNCE_MS, function()
        timers[changed_bufnr] = nil
        if
          vim.api.nvim_buf_is_valid(changed_bufnr)
          and vim.api.nvim_buf_get_changedtick(changed_bufnr) == changedtick
        then
          M.sync(changed_bufnr)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    buffer = bufnr,
    callback = function(args)
      stop_timer(args.buf)
      trackers[args.buf] = nil
    end,
  })

  attach(bufnr)
end

---Stop watching one buffer.
---@param bufnr integer Buffer number (0 for current)
---@return nil
function M.disable(bufnr)
  bufnr = resolve(bufnr)
  stop_timer(bufnr)
  trackers[bufnr] = nil
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP_PREFIX .. bufnr)
end

---Stop watching every buffer.
---@return nil
function M.teardown()
  for bufnr in pairs(timers) do
    stop_timer(bufnr)
  end
  trackers = {}

  local groups = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({})) do
    local name = autocmd.group_name
    if name and name:sub(1, #AUGROUP_PREFIX) == AUGROUP_PREFIX then
      groups[name] = true
    end
  end
  for name in pairs(groups) do
    vim.api.nvim_del_augroup_by_name(name)
  end
end

return M
