-- spec/helpers/mocks.lua
-- Mock factories for vim APIs used across markdown-plus.nvim tests
-- Provides deterministic substitutes for vim.ui.input, vim.ui.select,
-- vim.notify, vim.schedule, vim.fn.input, and other interactive APIs.

local M = {}

--- Mock vim.fn.input to return queued responses
--- Also patches vim.ui.input when present.
---@param responses string[] Ordered list of return values
---@return table spy with .calls and .restore()
function M.mock_input(responses)
  local queue = vim.deepcopy(responses or {})
  local spy_data = { calls = {} }

  -- Save originals
  local orig_fn_input = vim.fn.input
  local orig_ui_input = vim.ui.input

  vim.fn.input = function(prompt, ...)
    table.insert(spy_data.calls, { prompt = prompt })
    if #queue > 0 then
      return table.remove(queue, 1)
    end
    return "" -- default for exhausted queue
  end

  vim.ui.input = function(opts, on_confirm)
    table.insert(spy_data.calls, { opts = opts })
    local value = #queue > 0 and table.remove(queue, 1) or nil
    if on_confirm then
      on_confirm(value)
    end
  end

  spy_data.restore = function()
    vim.fn.input = orig_fn_input
    vim.ui.input = orig_ui_input
  end

  return spy_data
end

--- Mock vim.ui.select to invoke callback with a chosen item
---@param choice_index number|nil Index of item to select (1-based), or nil for cancel
---@return table spy with .calls and .restore()
function M.mock_select(choice_index)
  local spy_data = { calls = {} }
  local orig = vim.ui.select

  vim.ui.select = function(items, opts, on_choice)
    table.insert(spy_data.calls, { items = items, opts = opts })
    if choice_index and items[choice_index] then
      on_choice(items[choice_index])
    else
      on_choice(nil)
    end
  end

  spy_data.restore = function()
    vim.ui.select = orig
  end

  return spy_data
end

--- Mock vim.notify to capture notifications
---@return table spy with .calls (each: {msg, level, opts}) and .restore()
function M.mock_notify()
  local spy_data = { calls = {} }
  local orig = vim.notify

  vim.notify = function(msg, level, opts)
    table.insert(spy_data.calls, { msg = msg, level = level, opts = opts })
  end

  spy_data.restore = function()
    vim.notify = orig
  end

  return spy_data
end

--- Mock vim.schedule to capture callbacks for synchronous flushing
---@return table spy with .callbacks, .flush(), .calls_count, and .restore()
function M.mock_schedule()
  local spy_data = { callbacks = {}, calls_count = 0 }
  local orig = vim.schedule

  vim.schedule = function(fn)
    spy_data.calls_count = spy_data.calls_count + 1
    table.insert(spy_data.callbacks, fn)
  end

  --- Execute all captured vim.schedule callbacks synchronously
  spy_data.flush = function()
    local cbs = spy_data.callbacks
    spy_data.callbacks = {}
    for _, cb in ipairs(cbs) do
      cb()
    end
  end

  spy_data.restore = function()
    vim.schedule = orig
  end

  return spy_data
end

--- Mock vim.cmd to capture command invocations
---@param passthrough? boolean If true, also run the real vim.cmd (default: false)
---@return table spy with .calls and .restore()
function M.mock_cmd(passthrough)
  local spy_data = { calls = {} }
  local orig = vim.cmd

  vim.cmd = function(cmd_str)
    table.insert(spy_data.calls, cmd_str)
    if passthrough then
      orig(cmd_str)
    end
  end

  spy_data.restore = function()
    vim.cmd = orig
  end

  return spy_data
end

--- Stub a module function temporarily
---@param mod table The module table
---@param fn_name string Function name to stub
---@param replacement function Replacement function
---@return table with .calls (forwarded args) and .restore()
function M.stub_fn(mod, fn_name, replacement)
  local spy_data = { calls = {} }
  local orig = mod[fn_name]

  mod[fn_name] = function(...)
    local args = { ... }
    table.insert(spy_data.calls, args)
    return replacement(...)
  end

  spy_data.restore = function()
    mod[fn_name] = orig
  end

  return spy_data
end

return M
