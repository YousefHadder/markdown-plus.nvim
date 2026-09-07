-- List auto-renumber autocommands for markdown-plus.nvim
-- Debounced renumbering of ordered lists plus per-buffer timer/augroup cleanup.
local parser = require("markdown-plus.list.parser")
local renumber = require("markdown-plus.list.renumber")
local shared = require("markdown-plus.list.shared")

local M = {}

local RENUMBER_DEBOUNCE_MS = 150
local ORDERED_LOOKAROUND = 20
local RENUMBER_AUGROUP_PREFIX = "MarkdownPlusListRenumber_"

---Per-buffer debounce timer handles, keyed by buffer number.
---@type table<integer, integer>
M.renumber_timers = {}

---Keep requests alive after timer expiry until their scheduled callback is consumed.
---@type table<integer, { changedtick: integer, sequence: integer }>
local pending_requests = {}

---Get the cursor row for a buffer, even when it is not the current buffer.
---@param bufnr integer Buffer number
---@return integer row 1-indexed cursor row
function M.get_cursor_row_for_buffer(bufnr)
  if vim.api.nvim_get_current_buf() == bufnr then
    return vim.api.nvim_win_get_cursor(0)[1]
  end

  local row = 1
  vim.api.nvim_buf_call(bufnr, function()
    row = vim.api.nvim_win_get_cursor(0)[1]
  end)
  return row
end

---Check whether an orderable list exists within the lookaround window of a row.
---@param bufnr integer Buffer number
---@param row integer 1-indexed row to search around
---@return boolean
function M.has_ordered_list_near_row(bufnr, row)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_row = math.max(1, row - ORDERED_LOOKAROUND)
  local end_row = math.min(line_count, row + ORDERED_LOOKAROUND)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

  for idx, line in ipairs(lines) do
    local line_row = start_row + idx - 1
    local list_info = parser.parse_list_line(line, line_row)
    if list_info and shared.is_orderable_type(list_info.type) then
      return true
    end
  end

  return false
end

---Whether a buffer sits at the newest state of its undo tree.
---
---A fresh edit always lands on the newest sequence number, so `seq_cur == seq_last`.
---Undo — and redo onto an interior state — move to a state that already exists, leaving
---`seq_cur < seq_last`.
---
---Renumbering must not run in that position. The write would create a *new* undo state on
---top of the one the user just undid to, so the next `u` would undo the renumber instead of
---moving further back, and every subsequent `u` would mint another state: the buffer stops
---moving and undo is stuck for good. That only bites when the restored text is not already
---canonically numbered (lazy `1.` markers, a list starting at some other number, gaps, or
---non-default marker spacing), which is why it looks intermittent.
---@param bufnr integer Buffer number
---@return boolean
function M.is_at_undo_tip(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local tree
  local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
    tree = vim.fn.undotree()
  end)

  -- Without a readable undo tree, assume the tip so renumbering keeps its normal behavior.
  if not ok or type(tree) ~= "table" or not tree.seq_cur or not tree.seq_last then
    return true
  end

  return tree.seq_cur >= tree.seq_last
end

---Stop and clear the debounce timer for a buffer, if one is pending.
---@param bufnr integer Buffer number
---@return nil
function M.stop_debounce_timer(bufnr)
  pending_requests[bufnr] = nil
  local timer_id = M.renumber_timers[bufnr]
  if timer_id then
    pcall(vim.fn.timer_stop, timer_id)
    M.renumber_timers[bufnr] = nil
  end
end

---Set up auto-renumber autocommands for the current buffer.
---@return nil
function M.setup_renumber_autocmds()
  local current_bufnr = vim.api.nvim_get_current_buf()
  M.stop_debounce_timer(current_bufnr)
  local group = vim.api.nvim_create_augroup(RENUMBER_AUGROUP_PREFIX .. current_bufnr, { clear = true })

  -- Normal-mode edits: renumber immediately.
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    buffer = current_bufnr,
    callback = function(args)
      local changed_bufnr = args.buf
      M.stop_debounce_timer(changed_bufnr)
      if not vim.api.nvim_buf_is_valid(changed_bufnr) or not vim.bo[changed_bufnr].modifiable then
        return
      end
      if not M.is_at_undo_tip(changed_bufnr) then
        return
      end
      local cursor_row = M.get_cursor_row_for_buffer(changed_bufnr)
      if not M.has_ordered_list_near_row(changed_bufnr, cursor_row) then
        return
      end

      vim.api.nvim_buf_call(changed_bufnr, function()
        -- Automatic renumbering rides along with the edit that caused it, so one `u`
        -- unwinds both. Manual renumbering stays its own undo step.
        renumber.renumber_ordered_lists({ undojoin = true })
      end)
    end,
  })

  -- Insert-mode edits: debounce to avoid renumbering on every keystroke.
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = current_bufnr,
    callback = function(args)
      local changed_bufnr = args.buf
      -- Invalidate before the proximity/undo guards: a distant edit or undo also retires
      -- the previous request, including work already queued through vim.schedule.
      M.stop_debounce_timer(changed_bufnr)
      if not vim.api.nvim_buf_is_valid(changed_bufnr) or not vim.bo[changed_bufnr].modifiable then
        return
      end
      if not M.is_at_undo_tip(changed_bufnr) then
        return
      end
      local cursor_row = M.get_cursor_row_for_buffer(changed_bufnr)
      if not M.has_ordered_list_near_row(changed_bufnr, cursor_row) then
        return
      end

      local request = {
        changedtick = vim.api.nvim_buf_get_changedtick(changed_bufnr),
        sequence = vim.api.nvim_buf_call(changed_bufnr, function()
          return vim.fn.undotree().seq_cur
        end),
      }
      pending_requests[changed_bufnr] = request

      M.renumber_timers[changed_bufnr] = vim.fn.timer_start(RENUMBER_DEBOUNCE_MS, function()
        if pending_requests[changed_bufnr] ~= request then
          return
        end
        M.renumber_timers[changed_bufnr] = nil
        vim.schedule(function()
          if pending_requests[changed_bufnr] ~= request then
            return
          end
          pending_requests[changed_bufnr] = nil
          if not vim.api.nvim_buf_is_valid(changed_bufnr) or not vim.bo[changed_bufnr].modifiable then
            return
          end
          -- A new undo branch can be at the tip too. Match the originating edit, even
          -- when its successor's TextChanged event has not been delivered yet.
          if vim.api.nvim_buf_get_changedtick(changed_bufnr) ~= request.changedtick then
            return
          end
          vim.api.nvim_buf_call(changed_bufnr, function()
            local tree = vim.fn.undotree()
            if tree.seq_cur ~= request.sequence or tree.seq_cur < tree.seq_last then
              return
            end
            renumber.renumber_ordered_lists({ undojoin = true })
          end)
        end)
      end)
    end,
  })

  -- Ensure timers are cleaned up for deleted buffers.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    buffer = current_bufnr,
    callback = function(args)
      M.stop_debounce_timer(args.buf)
    end,
  })
end

---Tear down list autocommand runtime state: stop all timers and remove the
---per-buffer renumber augroups.
---@return nil
function M.teardown()
  pending_requests = {}
  local bufnrs = {}
  for bufnr in pairs(M.renumber_timers) do
    table.insert(bufnrs, bufnr)
  end
  for _, bufnr in ipairs(bufnrs) do
    M.stop_debounce_timer(bufnr)
  end

  local autocmds = vim.api.nvim_get_autocmds({})
  local groups = {}
  for _, autocmd in ipairs(autocmds) do
    local group_name = autocmd.group_name
    if group_name and group_name:sub(1, #RENUMBER_AUGROUP_PREFIX) == RENUMBER_AUGROUP_PREFIX then
      groups[group_name] = true
    end
  end

  for group_name in pairs(groups) do
    vim.api.nvim_del_augroup_by_name(group_name)
  end
end

return M
