-- Tests for markdown-plus thematic break module
describe("markdown-plus thematic break", function()
  local thematic_break = require("markdown-plus.thematic_break")
  local utils = require("markdown-plus.utils")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    thematic_break.setup({
      keymaps = { enabled = true },
      thematic_break = { style = "---" },
    })
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("insert", function()
    it("inserts a thematic break below cursor with surrounding blank lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Line 1", "Line 2" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      thematic_break.insert()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "Line 1", "", "---", "", "Line 2" }, lines)
    end)

    it("does not add an extra blank line above when current line is blank", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "", "Paragraph" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      thematic_break.insert()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "", "---", "", "Paragraph" }, lines)
    end)

    it("uses configured insertion style", function()
      thematic_break.setup({
        keymaps = { enabled = true },
        thematic_break = { style = "***" },
      })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Title" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      thematic_break.insert()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "Title", "", "***" }, lines)
    end)
  end)

  describe("cycle_style", function()
    it("cycles thematic break styles on current line", function()
      utils.set_line(1, "  ---")
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      thematic_break.cycle_style()
      assert.are.equal("  ***", utils.get_line(1))

      thematic_break.cycle_style()
      assert.are.equal("  ___", utils.get_line(1))

      thematic_break.cycle_style()
      assert.are.equal("  ---", utils.get_line(1))
    end)

    it("warns and leaves line unchanged when not on a thematic break", function()
      utils.set_line(1, "Not a break")
      local original_notify = vim.notify
      local warned = false

      vim.notify = function(msg, level)
        if msg:match("not a thematic break") and level == vim.log.levels.WARN then
          warned = true
        end
      end

      thematic_break.cycle_style()

      vim.notify = original_notify
      assert.is_true(warned)
      assert.are.equal("Not a break", utils.get_line(1))
    end)
  end)

  describe("setup_keymaps", function()
    it("sets default keymaps for thematic break operations", function()
      thematic_break.setup_keymaps()

      local insert_map = vim.fn.maparg("<localleader>mh", "n", false, true)
      local cycle_map = vim.fn.maparg("<localleader>mH", "n", false, true)

      assert.are.equal("<Plug>(MarkdownPlusInsertThematicBreak)", insert_map.rhs)
      assert.are.equal("<Plug>(MarkdownPlusCycleThematicBreak)", cycle_map.rhs)
    end)
  end)
end)
