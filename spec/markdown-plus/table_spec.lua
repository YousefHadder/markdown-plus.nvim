---@diagnostic disable: undefined-field
local parser = require("markdown-plus.table.parser")
local formatter = require("markdown-plus.table.format")

describe("table.parser", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("get_table_at_cursor", function()
    it("should parse a simple table", function()
      local lines = {
        "| Header 1 | Header 2 |",
        "| --- | --- |",
        "| Cell 1 | Cell 2 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(1, table_info.start_row)
      assert.equals(3, table_info.end_row)
      assert.equals(2, table_info.cols)
      assert.equals("Header 1", table_info.cells[1][1])
      assert.equals("Header 2", table_info.cells[1][2])
    end)

    it("should detect column alignments", function()
      local lines = {
        "| Left | Center | Right |",
        "| --- | :---: | ---: |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals("left", table_info.alignments[1])
      assert.equals("center", table_info.alignments[2])
      assert.equals("right", table_info.alignments[3])
    end)

    it("should return nil when not in a table", function()
      local lines = { "Just some text" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.is_nil(table_info)
    end)

    it("should handle tables with empty cells", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | | C |",
        "| | B | |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(3, table_info.cols)
      assert.equals("", table_info.cells[2][2])
      assert.equals("", table_info.cells[3][1])
    end)
  end)

  describe("get_cursor_position_in_table", function()
    it("should determine cursor position in table", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 5) -- In second cell of data row

      local pos = parser.get_cursor_position_in_table()
      assert.is_not_nil(pos)
      assert.equals(2, pos.row) -- 0=header, 1=separator, 2=first data row
    end)
  end)
end)

describe("table.formatter", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("format_table", function()
    it("should align columns properly", function()
      local lines = {
        "| Short | Long Header |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Check that columns are padded
      assert.truthy(result[1]:match("Short"))
      assert.truthy(result[2]:match("%-%-%-"))
    end)

    it("should handle different alignments", function()
      local lines = {
        "| L | C | R |",
        "| --- | :---: | ---: |",
        "| Left | Center | Right |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Separator should preserve alignment markers
      assert.truthy(result[2]:match("%-%-%-"))
      assert.truthy(result[2]:match(":%-+:"))
      assert.truthy(result[2]:match("%-+:"))
    end)

    it("should handle malformed tables with missing pipes", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should properly format all rows with pipes
      assert.truthy(result[3]:match("^|.*|$"))
    end)

    it("should handle tables with no spacing around pipes", function()
      local lines = {
        "|H1|H2|H3|",
        "|---|---|---|",
        "|A|B|C|",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should add proper spacing with pipes and content
      assert.truthy(result[1]:match("^|"))
      assert.truthy(result[1]:match("|$"))
      assert.truthy(result[1]:match("H1"))
      assert.truthy(result[1]:match("H2"))
      assert.truthy(result[1]:match("H3"))
    end)

    it("should handle tables with excessive spacing", function()
      local lines = {
        "|   H1   |   H2   |   H3   |",
        "|  ---   |  ---   |  ---   |",
        "|   A    |   B    |   C    |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should normalize spacing (content preserved, consistent formatting)
      assert.truthy(result[1]:match("H1"))
      assert.truthy(result[1]:match("H2"))
      assert.truthy(result[1]:match("H3"))
      -- Check it's properly formatted with pipes
      local _, pipe_count = result[1]:gsub("|", "")
      assert.equals(4, pipe_count) -- 3 columns = 4 pipes
    end)

    it("should handle mixed column widths correctly", function()
      local lines = {
        "| A | B | C |",
        "| --- | --- | --- |",
        "| Very Long Content | Short | Medium Width |",
        "| X | Y | Z |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- First column should accommodate "Very Long Content"
      -- Check that long content is preserved
      assert.truthy(result[3]:match("Very Long Content"))
      -- Check that all rows are properly formatted with 3 columns
      local _, pipes1 = result[1]:gsub("|", "")
      local _, pipes3 = result[3]:gsub("|", "")
      assert.equals(4, pipes1)
      assert.equals(4, pipes3)
    end)

    it("should handle single column tables", function()
      local lines = {
        "| Header |",
        "| --- |",
        "| Cell 1 |",
        "| Cell 2 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(4, #result)
      assert.truthy(result[1]:match("^| Header |$"))
    end)

    it("should handle wide tables with many columns", function()
      local lines = {
        "| C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
        "| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      assert.equals(8, table_info.cols)
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should handle all 8 columns
      local _, pipe_count = result[1]:gsub("|", "")
      assert.equals(9, pipe_count) -- 8 columns = 9 pipes
    end)

    it("should handle all empty cells", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| | | |",
        "| | | |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Empty cells should be formatted with spaces
      assert.truthy(result[3]:match("^|%s+|%s+|%s+|$"))
    end)

    it("should handle special characters in cells", function()
      local lines = {
        "| Header | Special |",
        "| --- | --- |",
        "| Code `test` | [Link](url) |",
        "| *Bold* | _Italic_ |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Special characters should be preserved
      assert.truthy(result[3]:match("`test`"))
      assert.truthy(result[3]:match("%[Link%]%(url%)"))
      assert.truthy(result[4]:match("%*Bold%*"))
    end)

    it("should handle unicode and multibyte characters", function()
      local lines = {
        "| English | 中文 | Emoji |",
        "| --- | --- | --- |",
        "| Hello | 你好 | 😀 |",
        "| World | 世界 | 🌍 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should preserve unicode characters
      assert.truthy(result[3]:match("你好"))
      assert.truthy(result[3]:match("😀"))
    end)

    it("should handle numbers and preserve formatting", function()
      local lines = {
        "| Integer | Float | Scientific |",
        "| --- | --- | --- |",
        "| 42 | 3.14159 | 1.23e-4 |",
        "| -100 | -99.99 | 2.5E+10 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Numbers should be preserved exactly
      assert.truthy(result[3]:match("3%.14159"))
      assert.truthy(result[3]:match("1%.23e%-4"))
    end)

    it("should handle mixed alignment with padding", function()
      local lines = {
        "| Left | Center | Right |",
        "|:---|:---:|---:|",
        "| A | BB | CCC |",
        "| DDDD | E | F |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Check alignment is preserved in separator
      -- Left alignment: starts with colon or just dashes
      assert.truthy(result[2]:match(":%-%-"))
      -- Center alignment: has colons on both sides
      assert.truthy(result[2]:match(":%-+:"))
      -- Right alignment: ends with colon
      assert.truthy(result[2]:match("%-+:"))
    end)

    it("should handle tables with leading/trailing whitespace", function()
      local lines = {
        "  | H1 | H2 |  ",
        "  | --- | --- |  ",
        "  | A | B |  ",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should normalize to standard format (starts and ends with pipe)
      assert.truthy(result[1]:match("^|"))
      assert.truthy(result[1]:match("|$"))
      assert.truthy(result[1]:match("H1"))
      assert.truthy(result[1]:match("H2"))
    end)

    it("should handle inconsistent column counts gracefully", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B |", -- Missing third column
        "| X | Y | Z | Extra |", -- Extra column
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should pad missing cells and handle gracefully
      local _, pipes_row3 = result[3]:gsub("|", "")
      assert.equals(4, pipes_row3) -- 3 columns = 4 pipes
    end)

    it("should preserve cell content order", function()
      local lines = {
        "| A | B | C | D |",
        "| --- | --- | --- | --- |",
        "| 1 | 2 | 3 | 4 |",
        "| W | X | Y | Z |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Content order must be preserved - check they appear in sequence
      local row3 = result[3]
      local pos1 = row3:find("1")
      local pos2 = row3:find("2")
      local pos3 = row3:find("3")
      local pos4 = row3:find("4")
      -- Numbers should appear in order
      assert.is_true(pos1 < pos2)
      assert.is_true(pos2 < pos3)
      assert.is_true(pos3 < pos4)
    end)

    it("should handle minimum column width", function()
      local lines = {
        "| A | B |",
        "| --- | --- |",
        "| X | Y |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Separator should have at least 3 dashes (minimum width)
      assert.truthy(result[2]:match("| %-%-%-+ |"))
    end)

    it("should handle cells with only whitespace", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "|    | A |",
        "| B |    |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local table_info = parser.get_table_at_cursor()
      formatter.format_table(table_info)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Whitespace-only cells should be treated as empty
      assert.is_not_nil(result[3])
      assert.is_not_nil(result[4])
    end)
  end)
end)

describe("table.manipulation", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  local manipulation = require("markdown-plus.table.manipulation")

  describe("insert_row", function()
    it("should insert row below", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 1) -- In data row

      local success = manipulation.insert_row(false)
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should have 4 content lines now (header, sep, 2 data rows)
      assert.equals(4, #result)
    end)
  end)

  describe("delete_row", function()
    it("should delete data row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 1) -- In first data row

      local success = manipulation.delete_row()
      assert.is_true(success)

      local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #result)
    end)

    it("should not delete header row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1) -- In header

      local success = manipulation.delete_row()
      assert.is_false(success)
    end)
  end)

  describe("insert_column", function()
    it("should insert column to the right", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 5) -- In first column

      local success = manipulation.insert_column(false)
      assert.is_true(success)

      -- Verify table now has 3 columns
      local table_info = parser.get_table_at_cursor()
      assert.equals(3, table_info.cols)
    end)
  end)

  describe("delete_column", function()
    it("should delete column", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 10) -- In middle column

      local success = manipulation.delete_column()
      assert.is_true(success)

      -- Verify table now has 2 columns
      local table_info = parser.get_table_at_cursor()
      assert.equals(2, table_info.cols)
    end)

    it("should not delete last column", function()
      local lines = {
        "| H1 |",
        "| --- |",
        "| A |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      local success = manipulation.delete_column()
      assert.is_false(success)
    end)
  end)
end)

describe("table.navigation", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("move_to_next_cell", function()
    it("should detect cursor in table", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First cell

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(3, table_info.cols)
    end)

    it("should work with formatted tables", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 1) -- First data row

      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(4, #table_info.rows) -- header + sep + 2 data rows
    end)
  end)
end)

describe("table.creator", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  local creator = require("markdown-plus.table.creator")

  describe("create_table", function()
    it("should create table with specified dimensions", function()
      creator.create_table(2, 3, "left")

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should have at least header + separator + 2 data rows (may have extra blank line)
      assert.is_true(#lines >= 4)

      -- Verify it's a valid table
      vim.fn.cursor(1, 1)
      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(3, table_info.cols)
    end)

    it("should respect alignment setting", function()
      creator.create_table(1, 2, "center")

      vim.fn.cursor(1, 1)
      local table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])
      assert.equals("center", table_info.alignments[2])
    end)
  end)
end)

describe("table.insert_mode_navigation", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  local navigation = require("markdown-plus.table.navigation")

  describe("move_right", function()
    it("should move to next cell in same row", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First cell of data row

      local before_col = vim.fn.col(".")
      local success = navigation.move_right()
      assert.is_true(success)

      local after_col = vim.fn.col(".")
      -- Should have moved to a different column position (right)
      assert.is_true(after_col > before_col)
    end)

    it("should wrap from last column to first column", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 9) -- Last cell

      local before_col = vim.fn.col(".")
      local success = navigation.move_right()
      assert.is_true(success) -- Should wrap
      local after_col = vim.fn.col(".")
      assert.is_true(after_col < before_col) -- Wrapped to first column
    end)

    it("should return false when not in table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a table" })
      vim.fn.cursor(1, 1)

      local success = navigation.move_right()
      assert.is_false(success)
    end)
  end)

  describe("move_left", function()
    it("should move to previous cell in same row", function()
      local lines = {
        "| H1 | H2 | H3 |",
        "| --- | --- | --- |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 10) -- Second cell

      local before_col = vim.fn.col(".")
      local success = navigation.move_left()
      assert.is_true(success)

      local after_col = vim.fn.col(".")
      -- Should have moved to a different column position (left)
      assert.is_true(after_col < before_col)
    end)

    it("should wrap from first column to last column", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First cell

      local before_col = vim.fn.col(".")
      local success = navigation.move_left()
      assert.is_true(success) -- Should wrap
      local after_col = vim.fn.col(".")
      assert.is_true(after_col > before_col) -- Wrapped to last column
    end)
  end)

  describe("move_down", function()
    it("should move to same column in next row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First data row, first cell

      local before_row = vim.fn.line(".")
      local success = navigation.move_down()
      assert.is_true(success)

      local after_row = vim.fn.line(".")
      assert.equals(4, after_row) -- Moved to next row
      assert.is_true(after_row > before_row)
    end)

    it("should skip separator when moving from header", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Header row

      local success = navigation.move_down()
      assert.is_true(success)

      local after_row = vim.fn.line(".")
      assert.equals(3, after_row) -- Skipped separator, moved to data row
    end)

    it("should wrap from last row to header", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- Last data row

      local success = navigation.move_down()
      assert.is_true(success) -- Should wrap
      local after_row = vim.fn.line(".")
      assert.equals(1, after_row) -- Wrapped to header
    end)
  end)

  describe("move_up", function()
    it("should move to same column in previous row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(4, 3) -- Second data row

      local before_row = vim.fn.line(".")
      local success = navigation.move_up()
      assert.is_true(success)

      local after_row = vim.fn.line(".")
      assert.equals(3, after_row) -- Moved to previous row
      assert.is_true(after_row < before_row)
    end)

    it("should skip separator when moving to header", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First data row

      local success = navigation.move_up()
      assert.is_true(success)

      local after_row = vim.fn.line(".")
      assert.equals(1, after_row) -- Skipped separator, moved to header
    end)

    it("should wrap from header to last row", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 3) -- Header row

      local success = navigation.move_up()
      assert.is_true(success) -- Should wrap
      local after_row = vim.fn.line(".")
      assert.equals(4, after_row) -- Wrapped to last data row
    end)
  end)

  describe("boundary_and_edge_cases", function()
    it("should handle navigation in single data row table", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

      -- Start in first cell of data row
      vim.fn.cursor(3, 3)
      -- Can move right
      assert.is_true(navigation.move_right())

      -- Now in second cell, can move back left
      assert.is_true(navigation.move_left())

      -- Back in first cell of data row, can move to header
      assert.is_true(navigation.move_up())

      -- Now in header, can move back down
      assert.is_true(navigation.move_down())
    end)

    it("should handle navigation in single column table", function()
      local lines = {
        "| H1 |",
        "| --- |",
        "| A |",
        "| B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 3) -- First data row
      local initial_pos = vim.fn.getcurpos()

      -- Moving left/right wraps to same column (visually stays in place)
      assert.is_true(navigation.move_left())
      local pos_after_left = vim.fn.getcurpos()
      assert.equals(initial_pos[2], pos_after_left[2]) -- Still in same row

      assert.is_true(navigation.move_right())
      local pos_after_right = vim.fn.getcurpos()
      assert.equals(initial_pos[2], pos_after_right[2]) -- Still in same row

      -- Can move down to second data row
      assert.is_true(navigation.move_down())

      -- From second data row, can move up
      assert.is_true(navigation.move_up())
    end)
  end)
end)

-- Phase 2 Tests
describe("table.manipulation Phase 2", function()
  local manipulation = require("markdown-plus.table.manipulation")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("toggle_cell_alignment", function()
    it("should cycle through alignments: left → center → right → left", function()
      local lines = {
        "| Column 1 | Column 2 |",
        "| --- | --- |",
        "| A | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 5) -- First column

      -- Should be left initially
      local table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])

      -- Toggle to center
      manipulation.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("center", table_info.alignments[1])

      -- Toggle to right
      manipulation.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("right", table_info.alignments[1])

      -- Toggle back to left
      manipulation.toggle_cell_alignment()
      table_info = parser.get_table_at_cursor()
      assert.equals("left", table_info.alignments[1])
    end)
  end)

  describe("move_row_up", function()
    it("should move data row up", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Row1 | A |",
        "| Row2 | B |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(4, 5) -- Row2

      manipulation.move_row_up()
      local table_info = parser.get_table_at_cursor()
      assert.equals("Row2", table_info.cells[2][1])
      assert.equals("Row1", table_info.cells[3][1])
    end)

    it("should not move first data row up", function()
      local lines = {
        "| H1 |",
        "| --- |",
        "| Row1 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 5) -- First data row

      local result = manipulation.move_row_up()
      assert.is_false(result)
    end)
  end)

  describe("move_row_down", function()
    it("should move data row down", function()
      local lines = {
        "| H1 |",
        "| --- |",
        "| Row1 |",
        "| Row2 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 5) -- Row1

      manipulation.move_row_down()
      local table_info = parser.get_table_at_cursor()
      assert.equals("Row2", table_info.cells[2][1])
      assert.equals("Row1", table_info.cells[3][1])
    end)
  end)

  describe("clear_cell", function()
    it("should clear cell content", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| Data | More |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(3, 5) -- First cell

      manipulation.clear_cell()
      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[2][1])
      assert.equals("More", table_info.cells[2][2]) -- Other cell unchanged
    end)
  end)

  describe("move_column_left", function()
    it("should swap column with left neighbor", function()
      local lines = {
        "| Col1 | Col2 | Col3 |",
        "| --- | :---: | ---: |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 15) -- Col2

      manipulation.move_column_left()
      local table_info = parser.get_table_at_cursor()
      assert.equals("Col2", table_info.cells[1][1])
      assert.equals("Col1", table_info.cells[1][2])
      -- Check alignments swapped too
      assert.equals("center", table_info.alignments[1])
      assert.equals("left", table_info.alignments[2])
    end)
  end)

  describe("move_column_right", function()
    it("should swap column with right neighbor", function()
      local lines = {
        "| Col1 | Col2 | Col3 |",
        "| :--- | --- | ---: |",
        "| A | B | C |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 5) -- Col1

      manipulation.move_column_right()
      local table_info = parser.get_table_at_cursor()
      assert.equals("Col2", table_info.cells[1][1])
      assert.equals("Col1", table_info.cells[1][2])
    end)
  end)
end)

describe("table.calculator", function()
  local calculator = require("markdown-plus.table.calculator")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    -- Disable confirmation prompts for tests
    require("markdown-plus.table").config.confirm_destructive = false
  end)

  describe("transpose_table", function()
    it("should swap rows and columns", function()
      -- Create a 2x4 table (2 cols, 4 rows including header)
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
        "| E | F |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      calculator.transpose_table()
      local table_info = parser.get_table_at_cursor()

      -- Original: 4 rows x 2 cols → Transposed: 2 rows x 4 cols
      assert.equals(4, table_info.cols) -- Now 4 columns
      assert.equals(2, #table_info.cells) -- Now 2 rows (including header)
      assert.equals("H1", table_info.cells[1][1])
      assert.equals("A", table_info.cells[1][2])
      assert.equals("C", table_info.cells[1][3])
      assert.equals("E", table_info.cells[1][4])
      assert.equals("H2", table_info.cells[2][1])
      assert.equals("B", table_info.cells[2][2])
      assert.equals("D", table_info.cells[2][3])
      assert.equals("F", table_info.cells[2][4])
    end)
  end)

  describe("sort_by_column", function()
    it("should sort numeric column ascending", function()
      local lines = {
        "| Name | Age |",
        "| --- | --- |",
        "| Alice | 30 |",
        "| Bob | 25 |",
        "| Charlie | 35 |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 15) -- Age column

      calculator.sort_by_column(true)
      local table_info = parser.get_table_at_cursor()
      assert.equals("Bob", table_info.cells[2][1])
      assert.equals("Alice", table_info.cells[3][1])
      assert.equals("Charlie", table_info.cells[4][1])
    end)

    it("should sort text column alphabetically", function()
      local lines = {
        "| Name | City |",
        "| --- | --- |",
        "| Charlie | Chicago |",
        "| Alice | Austin |",
        "| Bob | Boston |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 5) -- Name column

      calculator.sort_by_column(true)
      local table_info = parser.get_table_at_cursor()
      assert.equals("Alice", table_info.cells[2][1])
      assert.equals("Bob", table_info.cells[3][1])
      assert.equals("Charlie", table_info.cells[4][1])
    end)
  end)
end)

describe("table.conversion", function()
  local conversion = require("markdown-plus.table.conversion")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  describe("table_to_csv", function()
    it("should convert simple table to CSV", function()
      local lines = {
        "| H1 | H2 |",
        "| --- | --- |",
        "| A | B |",
        "| C | D |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      conversion.table_to_csv()
      local result_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(3, #result_lines)
      assert.equals("H1,H2", result_lines[1])
      assert.equals("A,B", result_lines[2])
    end)

    it("should quote fields with commas", function()
      local lines = {
        "| Name | Description |",
        "| --- | --- |",
        "| Item1 | Red, blue |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      conversion.table_to_csv()
      local result_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(result_lines[2]:match('"Red, blue"') ~= nil)
    end)
  end)

  describe("csv_to_table", function()
    it("should convert simple CSV to table", function()
      local lines = {
        "H1,H2",
        "A,B",
        "C,D",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      conversion.csv_to_table()
      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals(2, table_info.cols)
      assert.equals("H1", table_info.cells[1][1])
      assert.equals("A", table_info.cells[2][1])
    end)

    it("should handle quoted fields with commas", function()
      local lines = {
        "Name,Description",
        '"Item1","Red, blue"',
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.fn.cursor(1, 1)

      conversion.csv_to_table()
      local table_info = parser.get_table_at_cursor()
      assert.equals("Red, blue", table_info.cells[2][2])
    end)
  end)
end)
