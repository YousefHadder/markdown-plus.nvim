---@diagnostic disable: undefined-field
local creator = require("markdown-plus.table.creator")
local mocks = require("spec.helpers.mocks")

describe("markdown-plus table creator", function()
  local notify_spy

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    notify_spy = mocks.mock_notify()
  end)

  after_each(function()
    notify_spy.restore()
    vim.cmd("bdelete!")
  end)

  describe("create_table", function()
    it("creates a 2x3 table with left alignment by default", function()
      creator.create_table(2, 3)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Header row
      assert.is_true(lines[1]:find("Header 1") ~= nil)
      assert.is_true(lines[1]:find("Header 2") ~= nil)
      assert.is_true(lines[1]:find("Header 3") ~= nil)
      -- Separator row with left-aligned dashes (no colons)
      assert.is_true(lines[2]:find("---") ~= nil)
      assert.is_nil(lines[2]:find(":"))
      -- 2 data rows
      assert.is_not_nil(lines[3])
      assert.is_not_nil(lines[4])
      -- Total: header + separator + 2 data rows (+ possible trailing empty line)
      local table_lines = 0
      for _, line in ipairs(lines) do
        if line:match("^|") then
          table_lines = table_lines + 1
        end
      end
      assert.equals(4, table_lines)
    end)

    it("creates a 1x2 table with center alignment", function()
      creator.create_table(1, 2, "center")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Separator should contain colon-padded dashes (e.g. :------:)
      assert.is_true(lines[2]:find(":%-+-:") ~= nil)
    end)

    it("creates a 1x2 table with right alignment", function()
      creator.create_table(1, 2, "right")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Separator should contain ---:
      assert.is_true(lines[2]:find("%-%-%-:") ~= nil)
    end)

    it("shows error notification when rows is 0", function()
      creator.create_table(0, 3)

      assert.equals(1, #notify_spy.calls)
      assert.is_true(notify_spy.calls[1].msg:find("at least 1") ~= nil)
      assert.equals(vim.log.levels.ERROR, notify_spy.calls[1].level)
      -- Buffer should remain unchanged
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)

    it("shows error notification when table is too large", function()
      creator.create_table(101, 3)

      assert.equals(1, #notify_spy.calls)
      assert.is_true(notify_spy.calls[1].msg:find("too large") ~= nil)
      assert.equals(vim.log.levels.ERROR, notify_spy.calls[1].level)
      -- Buffer should remain unchanged
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)
  end)

  describe("create_table_interactive", function()
    it("creates a table with valid column and row input", function()
      local input_spy = mocks.mock_input({ "3", "2" })

      creator.create_table_interactive()

      input_spy.restore()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local table_lines = 0
      for _, line in ipairs(lines) do
        if line:match("^|") then
          table_lines = table_lines + 1
        end
      end
      -- header + separator + 2 data rows
      assert.equals(4, table_lines)
      -- Should have prompted twice
      assert.equals(2, #input_spy.calls)
    end)

    it("shows error when column input is empty", function()
      local input_spy = mocks.mock_input({ "" })

      creator.create_table_interactive()

      input_spy.restore()

      assert.equals(1, #notify_spy.calls)
      assert.is_true(notify_spy.calls[1].msg:find("Invalid column") ~= nil)
      -- Buffer should remain unchanged
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)

    it("shows error when column input is non-numeric", function()
      local input_spy = mocks.mock_input({ "abc" })

      creator.create_table_interactive()

      input_spy.restore()

      assert.equals(1, #notify_spy.calls)
      assert.is_true(notify_spy.calls[1].msg:find("Invalid column") ~= nil)
    end)

    it("shows error when columns valid but rows input is invalid", function()
      local input_spy = mocks.mock_input({ "3", "xyz" })

      creator.create_table_interactive()

      input_spy.restore()

      assert.equals(1, #notify_spy.calls)
      assert.is_true(notify_spy.calls[1].msg:find("Invalid row") ~= nil)
      -- Buffer should remain unchanged
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)
  end)
end)
