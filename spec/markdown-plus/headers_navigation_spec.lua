---Test suite for markdown-plus.nvim header navigation
---Tests next_header, prev_header, and follow_link functions
---@diagnostic disable: undefined-field
local helpers = require("spec.helpers")
local nav = require("markdown-plus.headers.navigation")

describe("markdown-plus headers navigation", function()
  local notify_spy

  before_each(function()
    helpers.create_buf({
      "# First Header",
      "Some text",
      "## Second Header",
      "More text",
      "### Third Header",
    })
    notify_spy = helpers.mocks.mock_notify()
  end)

  after_each(function()
    notify_spy.restore()
    helpers.destroy_buf()
  end)

  describe("next_header", function()
    it("moves cursor to the next header line", function()
      helpers.set_cursor(1, 0)
      nav.next_header()
      local pos = helpers.get_cursor()
      assert.are.equal(3, pos[1])
    end)

    it("notifies when there is no next header", function()
      helpers.set_cursor(5, 0)
      nav.next_header()
      local pos = helpers.get_cursor()
      assert.are.equal(5, pos[1])
      assert.are.equal(1, #notify_spy.calls)
      assert.are.equal("No next header", notify_spy.calls[1].msg)
      assert.are.equal(vim.log.levels.INFO, notify_spy.calls[1].level)
    end)
  end)

  describe("prev_header", function()
    it("moves cursor to the previous header line", function()
      helpers.set_cursor(5, 0)
      nav.prev_header()
      local pos = helpers.get_cursor()
      assert.are.equal(3, pos[1])
    end)

    it("notifies when there is no previous header", function()
      helpers.set_cursor(1, 0)
      nav.prev_header()
      local pos = helpers.get_cursor()
      assert.are.equal(1, pos[1])
      assert.are.equal(1, #notify_spy.calls)
      assert.are.equal("No previous header", notify_spy.calls[1].msg)
      assert.are.equal(vim.log.levels.INFO, notify_spy.calls[1].level)
    end)
  end)

  describe("follow_link", function()
    it("jumps to matching header and returns true", function()
      helpers.create_buf({
        "# First Header",
        "",
        "## Second Header",
        "",
        "- [Second Header](#second-header)",
      })
      helpers.set_cursor(5, 0)
      local result = nav.follow_link()
      assert.is_true(result)
      local pos = helpers.get_cursor()
      assert.are.equal(3, pos[1])
    end)

    it("notifies and returns false for non-existent anchor", function()
      helpers.create_buf({
        "# First Header",
        "",
        "- [Missing](#no-such-header)",
      })
      helpers.set_cursor(3, 0)
      local result = nav.follow_link()
      assert.is_false(result)
      assert.are.equal(1, #notify_spy.calls)
      assert.are.equal("Header not found: no-such-header", notify_spy.calls[1].msg)
      assert.are.equal(vim.log.levels.WARN, notify_spy.calls[1].level)
    end)

    it("returns false without notification on a non-link line", function()
      helpers.set_cursor(2, 0)
      local result = nav.follow_link()
      assert.is_false(result)
      assert.are.equal(0, #notify_spy.calls)
    end)
  end)
end)
