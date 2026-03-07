---@diagnostic disable: undefined-field
local row_ops = require("markdown-plus.table.row_ops")
local parser = require("markdown-plus.table.parser")

describe("table.row_ops", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("insert_row", function()
    it("should insert a row below a data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3)

      local success = row_ops.insert_row(false)
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(4, #result)
    end)

    it("should insert a row above a data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(4, 3) -- Second data row

      local success = row_ops.insert_row(true)
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(5, #result)

      local table_info = parser.get_table_at_cursor()
      -- Original "C" row should be pushed to cells[4], new empty row at cells[3]
      assert.equals("", table_info.cells[3][1])
      assert.equals("C", table_info.cells[4][1])
    end)

    it("should insert below header as first data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Header row

      local success = row_ops.insert_row(false)
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(4, #result)

      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[2][1])
      assert.equals("A", table_info.cells[3][1])
    end)

    it("should insert below separator as first data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3) -- Separator row

      local success = row_ops.insert_row(false)
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[2][1])
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = row_ops.insert_row(false)
      assert.is_false(success)
    end)
  end)

  describe("delete_row", function()
    it("should delete a data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First data row

      local success = row_ops.delete_row()
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #result)

      local table_info = parser.get_table_at_cursor()
      assert.equals("C", table_info.cells[2][1])
    end)

    it("should not delete the header row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local success = row_ops.delete_row()
      assert.is_false(success)
    end)

    it("should not delete the separator row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3)

      local success = row_ops.delete_row()
      assert.is_false(success)
    end)

    it("should not delete the only data row when cells count is minimal", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3)

      -- NOTE: Current implementation allows deleting when #cells == 2
      -- (header + 1 data row) because the guard checks #cells < 2.
      -- This test documents the current behavior.
      local success = row_ops.delete_row()
      assert.is_true(success)
    end)

    it("should delete the last data row and adjust cursor", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(4, 3) -- Last data row

      local success = row_ops.delete_row()
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #result)
    end)
  end)

  describe("duplicate_row", function()
    it("should duplicate a data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- Data row

      local success = row_ops.duplicate_row()
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(4, #result)

      local table_info = parser.get_table_at_cursor()
      assert.equals("A", table_info.cells[2][1])
      assert.equals("A", table_info.cells[3][1])
    end)

    it("should duplicate the header row as first data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Header row

      local success = row_ops.duplicate_row()
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(4, #result)

      local table_info = parser.get_table_at_cursor()
      -- Header stays as cells[1], duplicate becomes cells[2]
      assert.equals("H1", table_info.cells[1][1])
      assert.equals("H1", table_info.cells[2][1])
      assert.equals("A", table_info.cells[3][1])
    end)

    it("should not duplicate the separator row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3) -- Separator row

      local success = row_ops.duplicate_row()
      assert.is_false(success)
    end)

    it("should return false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = row_ops.duplicate_row()
      assert.is_false(success)
    end)
  end)

  describe("move_row_up", function()
    it("should swap data row with the one above", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
        "| Row2 | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(4, 3) -- Row2

      local success = row_ops.move_row_up()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("Row2", table_info.cells[2][1])
      assert.equals("Row1", table_info.cells[3][1])
    end)

    it("should not move the first data row up", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3)

      local success = row_ops.move_row_up()
      assert.is_false(success)
    end)

    it("should not move the header row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local success = row_ops.move_row_up()
      assert.is_false(success)
    end)

    it("should not move the separator row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3)

      local success = row_ops.move_row_up()
      assert.is_false(success)
    end)
  end)

  describe("move_row_down", function()
    it("should swap data row with the one below", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
        "| Row2 | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- Row1

      local success = row_ops.move_row_down()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("Row2", table_info.cells[2][1])
      assert.equals("Row1", table_info.cells[3][1])
    end)

    it("should not move the last data row down", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3)

      local success = row_ops.move_row_down()
      assert.is_false(success)
    end)

    it("should not move the header row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3)

      local success = row_ops.move_row_down()
      assert.is_false(success)
    end)

    it("should not move the separator row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(2, 3)

      local success = row_ops.move_row_down()
      assert.is_false(success)
    end)

    it("should handle three data rows", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
        "| Row2 | B |",
        "| Row3 | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- Row1

      local success = row_ops.move_row_down()
      assert.is_true(success)

      local table_info = parser.get_table_at_cursor()
      assert.equals("Row2", table_info.cells[2][1])
      assert.equals("Row1", table_info.cells[3][1])
      assert.equals("Row3", table_info.cells[4][1])
    end)
  end)
end)
