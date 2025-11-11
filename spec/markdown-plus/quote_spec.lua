-- Tests for markdown-plus quote module
describe("markdown-plus quote", function()
  local quote = require("markdown-plus.quote")
  local utils = require("markdown-plus.utils")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    quote.setup({
      enabled = true,
      features = {
        quotes = true,
      },
      keymaps = {
        enabled = true,
      },
      filetypes = { "markdown" },
    })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("toggle_quote_on_line", function()
    it("adds a blockquote to plain text", function()
      utils.set_line(1, "This is a plain text line.")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("> This is a plain text line.", line)
    end)

    it("removes a blockquote from quoted text", function()
      utils.set_line(1, "> This is a quoted text line.")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("This is a quoted text line.", line)
    end)

    it("handles whitespace correctly when adding a blockquote", function()
      utils.set_line(1, "   Leading spaces.")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal(">    Leading spaces.", line)
    end)

    it("handles whitespace correctly when removing a blockquote", function()
      utils.set_line(1, ">    Leading spaces.")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("   Leading spaces.", line)
    end)

    it("creates a blockquote on empty lines and enters insert mode", function()
      utils.set_line(1, "")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("> ", line)
      -- Check cursor position is at end of line (column 2)
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(1, cursor[1]) -- line number
      assert.are.equal(2, cursor[2]) -- column (0-indexed)
    end)

    it("handles lines without spaces after >", function()
      utils.set_line(1, ">No space after >")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("No space after >", line)
    end)
  end)

  describe("toggle_quote", function()
    it("adds blockquotes to selected lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "First line", "Second line", "Third line" })
      -- Simulate visual selection from line 1 to line 2
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 1, 0 })
      quote.toggle_quote()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("> First line", lines[1])
      assert.are.equal("> Second line", lines[2])
      assert.are.equal("Third line", lines[3])
    end)

    it("removes blockquotes from selected lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "> First line", "> Second line", "Third line" })
      -- Simulate visual selection from line 1 to line 2
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 1, 0 })
      quote.toggle_quote()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("First line", lines[1])
      assert.are.equal("Second line", lines[2])
      assert.are.equal("Third line", lines[3])
    end)

    it("handles mixed quoted and unquoted lines in visual selection", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "> Quoted line", "Unquoted line" })
      -- Simulate visual selection from line 1 to line 2
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 1, 0 })
      quote.toggle_quote()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("Quoted line", lines[1])
      assert.are.equal("> Unquoted line", lines[2])
    end)
  end)

  describe("edge cases", function()
    it("handles lines with only >", function()
      utils.set_line(1, ">")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("", line)
    end)

    it("handles lines with only whitespace and >", function()
      utils.set_line(1, ">   ")
      quote.toggle_quote_on_line(1)
      local line = utils.get_line(1)
      assert.are.equal("  ", line)
    end)
  end)
end)
