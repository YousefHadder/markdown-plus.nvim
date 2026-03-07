---@diagnostic disable: undefined-field
local column_ops = require("markdown-plus.table.column_ops")
local parser = require("markdown-plus.table.parser")

describe("table.column_ops", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("insert_column", function()
    it("should insert a column to the right", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      local success = column_ops.insert_column(false)
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
      assert.equals("H1", table_info.cells[1][1])
      assert.equals("", table_info.cells[1][2])
      assert.equals("H2", table_info.cells[1][3])
    end)

    it("should insert a column to the left", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      local success = column_ops.insert_column(true)
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
      assert.equals("", table_info.cells[1][1])
      assert.equals("H1", table_info.cells[1][2])
      assert.equals("H2", table_info.cells[1][3])
    end)

    it("should insert at the last column position", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- Second column

      local success = column_ops.insert_column(false)
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
      assert.equals("H2", table_info.cells[1][2])
      assert.equals("", table_info.cells[1][3])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = column_ops.insert_column(false)
      assert.is_false(success)
    end)
  end)

  describe("delete_column", function()
    it("should delete a column", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- Middle column

      local success = column_ops.delete_column()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(2, table_info.cols)
    end)

    it("should not delete the only column", function()
      local lines = {
        "| H1 |",
        "| --- |",
        "| A |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local success = column_ops.delete_column()
      assert.is_false(success)
    end)

    it("should delete the last column and adjust cursor", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- Second (last) column

      local success = column_ops.delete_column()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(1, table_info.cols)
      assert.equals("H1", table_info.cells[1][1])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = column_ops.delete_column()
      assert.is_false(success)
    end)
  end)

  describe("duplicate_column", function()
    it("should duplicate the current column", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      local success = column_ops.duplicate_column()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
      assert.equals("H1", table_info.cells[1][1])
      assert.equals("H1", table_info.cells[1][2])
      assert.equals("H2", table_info.cells[1][3])
      assert.equals("A", table_info.cells[2][1])
      assert.equals("A", table_info.cells[2][2])
    end)

    it("should duplicate the last column", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- Second column

      local success = column_ops.duplicate_column()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
      assert.equals("H2", table_info.cells[1][2])
      assert.equals("H2", table_info.cells[1][3])
    end)

    it("should preserve column alignment when duplicating", function()
      local lines = {
        "| H1 | H2 |",
        "| :---: | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column (center-aligned)

      local success = column_ops.duplicate_column()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])
      assert.equals("center", table_info.alignments[2])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = column_ops.duplicate_column()
      assert.is_false(success)
    end)
  end)

  describe("move_column_left", function()
    it("should swap column with the one to the left", function()
      local lines = {
        "| Col1 | Col2 | Col3 |",
        "| --- | :---: | ---: |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 15) -- Col2

      local success = column_ops.move_column_left()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("Col2", table_info.cells[1][1])
      assert.equals("Col1", table_info.cells[1][2])
      assert.equals("Col3", table_info.cells[1][3])
      -- Alignments should swap too
      assert.equals("center", table_info.alignments[1])
      assert.equals("left", table_info.alignments[2])
    end)

    it("should not move the leftmost column", function()
      local lines = {
        "| Col1 | Col2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      local success = column_ops.move_column_left()
      assert.is_false(success)
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = column_ops.move_column_left()
      assert.is_false(success)
    end)
  end)

  describe("move_column_right", function()
    it("should swap column with the one to the right", function()
      local lines = {
        "| Col1 | Col2 | Col3 |",
        "| :--- | --- | ---: |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Col1

      local success = column_ops.move_column_right()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("Col2", table_info.cells[1][1])
      assert.equals("Col1", table_info.cells[1][2])
      assert.equals("Col3", table_info.cells[1][3])
    end)

    it("should not move the rightmost column", function()
      local lines = {
        "| Col1 | Col2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- Last column

      local success = column_ops.move_column_right()
      assert.is_false(success)
    end)

    it("should swap data row content along with headers", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- First column

      local success = column_ops.move_column_right()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("H2", table_info.cells[1][1])
      assert.equals("H1", table_info.cells[1][2])
      assert.equals("B", table_info.cells[2][1])
      assert.equals("A", table_info.cells[2][2])
      assert.equals("D", table_info.cells[3][1])
      assert.equals("C", table_info.cells[3][2])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = column_ops.move_column_right()
      assert.is_false(success)
    end)
  end)
end)
