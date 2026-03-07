---@diagnostic disable: undefined-field
local cell_ops = require("markdown-plus.table.cell_ops")
local parser = require("markdown-plus.table.parser")

describe("table.cell_ops", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("clear_cell", function()
    it("should clear content of a data cell", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Data | More |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First cell of data row

      local success = cell_ops.clear_cell()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[2][1])
      assert.equals("More", table_info.cells[2][2])
    end)

    it("should clear content of a header cell", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Header cell

      local success = cell_ops.clear_cell()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[1][1])
      assert.equals("H2", table_info.cells[1][2])
    end)

    it("should not clear the separator row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3) -- Separator row

      local success = cell_ops.clear_cell()
      assert.is_false(success)
    end)

    it("should leave other cells unchanged", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
        "| D | E | F |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 7) -- Cell "B" (column 7 in "| A | B | C |")

      local success = cell_ops.clear_cell()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("A", table_info.cells[2][1])
      assert.equals("", table_info.cells[2][2])
      assert.equals("C", table_info.cells[2][3])
      assert.equals("D", table_info.cells[3][1])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = cell_ops.clear_cell()
      assert.is_false(success)
    end)
  end)

  describe("toggle_cell_alignment", function()
    it("should cycle left to center", function()
      local lines = {
        "| Column 1 | Column 2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])

      cell_ops.toggle_cell_alignment()

      table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])
    end)

    it("should cycle center to right", function()
      local lines = {
        "| Column 1 | Column 2 |",
        "| :---: | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column (center-aligned)

      cell_ops.toggle_cell_alignment()

      local table_info = parser.get_table_at_cursor()
      assert.equals("right", table_info.alignments[1])
    end)

    it("should cycle right to left", function()
      local lines = {
        "| Column 1 | Column 2 |",
        "| ---: | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column (right-aligned)

      cell_ops.toggle_cell_alignment()

      local table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])
    end)

    it("should complete full cycle left → center → right → left", function()
      local lines = {
        "| Column 1 | Column 2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])

      cell_ops.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])

      cell_ops.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("right", table_info.alignments[1])

      cell_ops.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])
    end)

    it("should only affect the current column alignment", function()
      local lines = {
        "| Col1 | Col2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      cell_ops.toggle_cell_alignment()

      local table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])
      assert.equals("left", table_info.alignments[2]) -- Unchanged
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = cell_ops.toggle_cell_alignment()
      assert.is_false(success)
    end)
  end)
end)
