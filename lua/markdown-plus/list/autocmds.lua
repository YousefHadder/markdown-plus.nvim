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

---Stop and clear the debounce timer for a buffer, if one is pending.
---@param bufnr integer Buffer number
---@return nil
function M.stop_debounce_timer(bufnr)
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
  local group = vim.api.nvim_create_augroup(RENUMBER_AUGROUP_PREFIX .. current_bufnr, { clear = true })

  -- Normal-mode edits: renumber immediately.
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    buffer = current_bufnr,
    callback = function(args)
      local changed_bufnr = args.buf
      if not vim.api.nvim_buf_is_valid(changed_bufnr) or not vim.bo[changed_bufnr].modifiable then
        return
      end
      local cursor_row = M.get_cursor_row_for_buffer(changed_bufnr)
      if not M.has_ordered_list_near_row(changed_bufnr, cursor_row) then
        return
      end

      vim.api.nvim_buf_call(changed_bufnr, function()
        renumber.renumber_ordered_lists()
      end)
    end,
  })

  -- Insert-mode edits: debounce to avoid renumbering on every keystroke.
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = current_bufnr,
    callback = function(args)
      local changed_bufnr = args.buf
      local cursor_row = M.get_cursor_row_for_buffer(changed_bufnr)
      if not M.has_ordered_list_near_row(changed_bufnr, cursor_row) then
        return
      end

      M.stop_debounce_timer(changed_bufnr)

      M.renumber_timers[changed_bufnr] = vim.fn.timer_start(RENUMBER_DEBOUNCE_MS, function()
        M.renumber_timers[changed_bufnr] = nil
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(changed_bufnr) or not vim.bo[changed_bufnr].modifiable then
            return
          end
          vim.api.nvim_buf_call(changed_bufnr, function()
            renumber.renumber_ordered_lists()
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
