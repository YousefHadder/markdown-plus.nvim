---@diagnostic disable: undefined-field
local guard = require("markdown-plus.keymap.guard")
local mocks = require("spec.helpers.mocks")

describe("keymap guard", function()
  local schedule
  local tick_stub
  local other_buf

  before_each(function()
    vim.cmd("enew")
    guard.reset()
    schedule = mocks.mock_schedule()
  end)

  after_each(function()
    if tick_stub then
      tick_stub.restore()
      tick_stub = nil
    end
    schedule.restore()
    guard.reset()
    if other_buf then
      vim.api.nvim_buf_delete(other_buf, { force = true })
      other_buf = nil
    end
    vim.cmd("bdelete!")
  end)

  it("consumes an armed bounce only once", function()
    assert.is_false(guard.consume_bounce("n", "x"))
    guard.arm("n", "x")
    assert.is_true(guard.consume_bounce("n", "x"))
    assert.is_false(guard.consume_bounce("n", "x"))
  end)

  it("distinguishes keys and modes", function()
    guard.arm("n", "x")
    assert.is_false(guard.consume_bounce("i", "x"))
    assert.is_false(guard.consume_bounce("n", "y"))
    assert.is_true(guard.consume_bounce("n", "x"))
  end)

  it("distinguishes buffers even when their changedticks match", function()
    tick_stub = mocks.stub_fn(vim.api, "nvim_buf_get_changedtick", function()
      return 7
    end)
    local first_buf = vim.api.nvim_get_current_buf()
    guard.arm("n", "x")
    other_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(other_buf)
    assert.is_false(guard.consume_bounce("n", "x"))
    vim.api.nvim_set_current_buf(first_buf)
    assert.is_true(guard.consume_bounce("n", "x"))
  end)

  it("allows a genuine repeat after the buffer changes", function()
    guard.arm("n", "x")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "changed" })
    assert.is_false(guard.consume_bounce("n", "x"))
    guard.arm("n", "x")
    assert.is_true(guard.consume_bounce("n", "x"))
  end)

  it("uses one scheduled sweep to release all guards in a burst", function()
    guard.arm("n", "x")
    guard.arm("i", "y")
    assert.are.equal(1, schedule.calls_count)
    schedule.flush()
    assert.is_false(guard.consume_bounce("n", "x"))
    assert.is_false(guard.consume_bounce("i", "y"))
    guard.arm("n", "x")
    assert.are.equal(2, schedule.calls_count)
  end)

  it("resets both guards and the scheduled-sweep flag", function()
    guard.arm("n", "x")
    guard.reset()
    assert.is_false(guard.consume_bounce("n", "x"))
    guard.arm("n", "x")
    assert.are.equal(2, schedule.calls_count)
    schedule.flush()
    assert.is_false(guard.consume_bounce("n", "x"))
  end)

  it("still protects re-entry when changedtick cannot be read", function()
    tick_stub = mocks.stub_fn(vim.api, "nvim_buf_get_changedtick", function()
      error("unavailable")
    end)
    guard.arm("n", "x")
    assert.is_true(guard.consume_bounce("n", "x"))
  end)
end)
