---Test suite for markdown-plus.nvim list normal_handler
---Tests backspace, normal-o, and normal-O handlers
---@diagnostic disable: undefined-field
local normal_handler = require("markdown-plus.list.normal_handler")
local list = require("markdown-plus.list")
local insert_mode = require("spec.helpers.insert_mode")

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
    -- Outside list context the handler no longer reimplements deletion; it defers to
    -- `keymap_fallback`, which queues keys. These cases therefore drive a real insert-mode
    -- session so the queued keys are flushed and their effect is observable.
    after_each(function()
      insert_mode.unmap_backspace_default()
    end)

    it("on non-list line deletes char", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
      insert_mode.map_backspace_default(normal_handler.handle_backspace)
      local result = insert_mode.backspace(1, 5)
      assert.are.equal("hell", result.lines[1])
    end)

    it("at start of non-list line joins with previous", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
      insert_mode.map_backspace_default(normal_handler.handle_backspace)
      local result = insert_mode.backspace(2, 0)
      assert.are.equal(1, #result.lines)
      assert.are.equal("firstsecond", result.lines[1])
    end)

    it("removes list marker", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("item", line)
    end)
  end)

  describe("handle_backspace fallback to foreign mappings", function()
    -- Simulates a mini.pairs-style global insert-mode `<BS>` mapping installed before
    -- markdown-plus shadows `<BS>` with its buffer-local default.
    local fired

    before_each(function()
      fired = false
      vim.keymap.set("i", "<BS>", function()
        fired = true
        return "<BS>"
      end, { expr = true, replace_keycodes = true })
    end)

    after_each(function()
      pcall(vim.keymap.del, "i", "<BS>")
    end)

    it("invokes the foreign mapping when the cursor is not in a list", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
    end)

    it("invokes the foreign mapping inside list item content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item text" })
      vim.api.nvim_win_set_cursor(0, { 1, 8 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
    end)

    it("removes the list marker without invoking the foreign mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      assert.are.equal("item", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      assert.is_false(fired)
    end)

    it("empties an empty list item marker without invoking the foreign mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- " })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      assert.are.equal("", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      assert.is_false(fired)
    end)

    it("ignores our own buffer-local default when resolving the fallback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.keymap.set("i", "<BS>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
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
