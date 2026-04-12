---Test suite for markdown-plus.nvim list normal_handler
---Tests backspace, normal-o, and normal-O handlers
---@diagnostic disable: undefined-field
local normal_handler = require("markdown-plus.list.normal_handler")
local list = require("markdown-plus.list")

describe("markdown-plus list normal_handler", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    -- Setup list module so parser works
    list.setup({
      enabled = true,
      features = { list_management = true },
      list = {
        smart_outdent = false,
        auto_renumber = true,
        html_block_awareness = true,
      },
    })
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("handle_backspace", function()
    it("on non-list line deletes char", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
      -- Enter insert mode so cursor can sit past the last char (col 5)
      vim.cmd("startinsert!")
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      normal_handler.handle_backspace()
      vim.cmd("stopinsert")
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("hell", line)
    end)

    it("at start of non-list line joins with previous", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      normal_handler.handle_backspace()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(1, #lines)
      assert.are.equal("firstsecond", lines[1])
    end)

    it("removes list marker", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("item", line)
    end)
  end)

  describe("handle_normal_o", function()
    it("on list item creates next item", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_o()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("- ", lines[2])
    end)

    it("on ordered list increments", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1. first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_o()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.is_truthy(lines[2]:match("^2%. "))
    end)

    it("on non-list inserts blank line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_o()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("", lines[2])
    end)
  end)

  describe("handle_normal_O", function()
    it("on list item creates prev item", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_O()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("- ", lines[1])
    end)
  end)
end)
