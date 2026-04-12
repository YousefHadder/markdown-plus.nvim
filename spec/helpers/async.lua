-- spec/helpers/async.lua
-- Async test utilities for markdown-plus.nvim
-- Provides deterministic flushing of vim.schedule queues

local M = {}

--- Flush all pending vim.schedule callbacks synchronously.
--- This works with the mock_schedule spy from spec/helpers/mocks.lua.
--- Usage:
---   local sched = mocks.mock_schedule()
---   -- trigger code that calls vim.schedule(fn)
---   async.flush_schedule(sched)
---   -- assert final state
---@param schedule_spy table The spy returned by mocks.mock_schedule()
---@param max_iterations? number Max flush cycles to prevent infinite loops (default: 10)
function M.flush_schedule(schedule_spy, max_iterations)
  max_iterations = max_iterations or 10
  local iteration = 0
  while #schedule_spy.callbacks > 0 and iteration < max_iterations do
    schedule_spy.flush()
    iteration = iteration + 1
  end
end

return M
