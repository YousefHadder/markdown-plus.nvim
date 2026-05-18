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

  describe("insert_break", function()
    local markdown_plus = require("markdown-plus")

    before_each(function()
      markdown_plus.setup({})
    end)

    after_each(function()
      markdown_plus.teardown()
    end)

    it("inserts <br> at the cursor position inside a data cell", function()
      local lines = {
        "| H1   | H2 |",
        "| ---- | -- |",
        "| word | y  |",
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      -- 0-indexed col 4 = byte position right after "| wo" (between 'o' and 'r')
      vim.api.nvim_win_set_cursor(0, { 3, 4 })

      assert.is_true(cell_ops.insert_break())

      local line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
      assert.equals("| wo<br>rd | y  |", line)

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1])
      assert.equals(4 + #"<br>", cursor[2])
    end)

    it("inserts the configured custom wrap_break", function()
      markdown_plus.setup({ table = { wrap_break = "|BRK|" } })

      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H |",
        "| - |",
        "| a |",
      })
      -- 0-indexed col 3 = byte position right after "| a" (between 'a' and ' ')
      vim.api.nvim_win_set_cursor(0, { 3, 3 })

      assert.is_true(cell_ops.insert_break())

      local line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
      assert.equals("| a|BRK| |", line)
    end)

    it("rejects the separator row", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | I |",
        "| - | - |",
        "| a | b |",
      })
      vim.fn.cursor(2, 3)

      assert.is_false(cell_ops.insert_break())
    end)

    it("returns false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.fn.cursor(1, 1)
      assert.is_false(cell_ops.insert_break())
    end)
  end)

  describe("wrap_cell", function()
    local markdown_plus = require("markdown-plus")

    before_each(function()
      markdown_plus.setup({})
    end)

    after_each(function()
      markdown_plus.teardown()
    end)

    local function place_cursor_at_cell(content_line, cell_text)
      -- Find a column inside the target cell on the given line.
      local line = vim.api.nvim_buf_get_lines(0, content_line - 1, content_line, false)[1]
      local s = line:find(cell_text, 1, true)
      assert.is_not_nil(s, "expected cell text to be present")
      vim.fn.cursor(content_line, s)
    end

    it("wraps a long cell at the explicit width using <br>", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| the quick brown fox | y |",
      })
      place_cursor_at_cell(3, "the")

      assert.is_true(cell_ops.wrap_cell(9))

      local table_info = parser.get_table_at_cursor()
      -- "the quick" (9) | "brown fox" (9)
      assert.equals("the quick<br>brown fox", table_info.cells[2][1])
    end)

    it("re-flows an already-broken cell when re-wrapped (idempotent at same width)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| the quick brown fox | y |",
      })
      place_cursor_at_cell(3, "the")

      assert.is_true(cell_ops.wrap_cell(9))
      local first = parser.get_table_at_cursor().cells[2][1]

      -- Find the cell again after potential layout shift
      place_cursor_at_cell(3, "the")
      assert.is_true(cell_ops.wrap_cell(9))
      local second = parser.get_table_at_cursor().cells[2][1]

      assert.equals(first, second)
    end)

    it("respects word boundaries (does not split a single long word)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| supercalifragilistic short | y |",
      })
      place_cursor_at_cell(3, "supercalifragilistic")

      assert.is_true(cell_ops.wrap_cell(8))

      local table_info = parser.get_table_at_cursor()
      -- The long word stays intact on its own line
      assert.is_truthy(table_info.cells[2][1]:find("supercalifragilistic", 1, true))
      -- And the short word ends up on a separate line via <br>
      assert.is_truthy(table_info.cells[2][1]:find("<br>", 1, true))
    end)

    it("uses config.max_column_width when no explicit width is given", function()
      markdown_plus.setup({ table = { max_column_width = 9 } })

      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| the quick brown fox | y |",
      })
      place_cursor_at_cell(3, "the")

      assert.is_true(cell_ops.wrap_cell())

      local table_info = parser.get_table_at_cursor()
      assert.equals("the quick<br>brown fox", table_info.cells[2][1])
    end)

    it("rejects the separator row", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| a | b |",
      })
      vim.fn.cursor(2, 3)
      assert.is_false(cell_ops.wrap_cell(10))
    end)

    it("returns false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.fn.cursor(1, 1)
      assert.is_false(cell_ops.wrap_cell(10))
    end)

    it("rejects non-positive widths", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H |",
        "| - |",
        "| a |",
      })
      vim.fn.cursor(3, 3)
      assert.is_false(cell_ops.wrap_cell(0))
      assert.is_false(cell_ops.wrap_cell(-3))
    end)

    it("treats inline-code spans as atomic when wrapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H                  | B |",
        "| ------------------ | - |",
        "| `foo bar` quux end | y |",
      })
      place_cursor_at_cell(3, "`foo")

      assert.is_true(cell_ops.wrap_cell(5))

      local table_info = parser.get_table_at_cursor()
      -- The code span "`foo bar`" must not be split by <br>.
      assert.is_truthy(table_info.cells[2][1]:find("`foo bar`", 1, true))
      assert.is_falsy(table_info.cells[2][1]:find("`foo<br>", 1, true))
    end)
  end)

  describe("unwrap_cell", function()
    local markdown_plus = require("markdown-plus")

    before_each(function()
      markdown_plus.setup({})
    end)

    after_each(function()
      markdown_plus.teardown()
    end)

    it("strips a single <br>", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H        | B |",
        "| -------- | - |",
        "| aa<br>bb | y |",
      })
      vim.fn.cursor(3, 4)

      assert.is_true(cell_ops.unwrap_cell())

      local table_info = parser.get_table_at_cursor()
      assert.equals("aa bb", table_info.cells[2][1])
    end)

    it("strips mixed <br>, <br/>, <br /> variants", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H                            | B |",
        "| ---------------------------- | - |",
        "| one<br>two<br/>three<br />four | y |",
      })
      vim.fn.cursor(3, 4)

      assert.is_true(cell_ops.unwrap_cell())

      local table_info = parser.get_table_at_cursor()
      assert.equals("one two three four", table_info.cells[2][1])
    end)

    it("is idempotent (no <br> left → second run is a no-op)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H        | B |",
        "| -------- | - |",
        "| aa<br>bb | y |",
      })
      vim.fn.cursor(3, 4)

      assert.is_true(cell_ops.unwrap_cell())
      local first = parser.get_table_at_cursor().cells[2][1]

      vim.fn.cursor(3, 4)
      assert.is_true(cell_ops.unwrap_cell())
      local second = parser.get_table_at_cursor().cells[2][1]

      assert.equals(first, second)
    end)

    it("rejects the separator row", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "| H | B |",
        "| - | - |",
        "| a | b |",
      })
      vim.fn.cursor(2, 3)
      assert.is_false(cell_ops.unwrap_cell())
    end)

    it("returns false when not in a table", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.fn.cursor(1, 1)
      assert.is_false(cell_ops.unwrap_cell())
    end)
  end)
end)
