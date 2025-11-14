---Test suite for markdown-plus.nvim utility functions
---Tests buffer detection, cursor operations, and line manipulation
---@diagnostic disable: undefined-field
local utils = require("markdown-plus.utils")

describe("markdown-plus utils", function()
  describe("is_markdown_buffer", function()
    it("returns true for markdown buffers", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
      vim.api.nvim_set_current_buf(buf)

      assert.is_true(utils.is_markdown_buffer())

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("always returns true (filetype filtering done by autocmd)", function()
      -- Note: is_markdown_buffer() always returns true because filetype
      -- filtering is handled by the autocmd pattern in init.lua.
      -- This allows the plugin to work with any configured filetype.
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "filetype", "lua")
      vim.api.nvim_set_current_buf(buf)

      assert.is_true(utils.is_markdown_buffer())

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("set_cursor", function()
    it("sets cursor to specified position", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "line 1",
        "line 2",
        "line 3",
      })
      vim.api.nvim_set_current_buf(buf)

      utils.set_cursor(2, 3)

      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(2, pos[1]) -- row (1-indexed)
      assert.are.equal(3, pos[2]) -- col (0-indexed)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_current_line", function()
    it("returns current line content", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "first line",
        "second line",
        "third line",
      })
      vim.api.nvim_set_current_buf(buf)

      utils.set_cursor(2, 0)
      local line = utils.get_current_line()

      assert.are.equal("second line", line)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("line operations", function()
    it("get_line retrieves specific line", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "first line",
        "second line",
        "third line",
      })
      vim.api.nvim_set_current_buf(buf)

      local line = utils.get_line(2)

      assert.are.equal("second line", line)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("set_line modifies specific line", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "first line",
        "second line",
        "third line",
      })
      vim.api.nvim_set_current_buf(buf)

      utils.set_line(2, "modified line")
      local line = utils.get_line(2)

      assert.are.equal("modified line", line)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_char_end_byte", function()
    it("returns correct byte index for ASCII characters", function()
      local line = "hello world"
      -- ASCII characters are 1 byte each, so end byte = input byte
      assert.are.equal(1, utils.get_char_end_byte(line, 1)) -- 'h'
      assert.are.equal(6, utils.get_char_end_byte(line, 6)) -- ' '
      assert.are.equal(11, utils.get_char_end_byte(line, 11)) -- 'd'
    end)

    it("returns correct byte index for multi-byte characters", function()
      local line = "这是一段文本" -- Each Chinese character is 3 bytes in UTF-8
      -- 这 = bytes 1-3
      assert.are.equal(3, utils.get_char_end_byte(line, 1))
      -- 是 = bytes 4-6
      assert.are.equal(6, utils.get_char_end_byte(line, 4))
      -- 一 = bytes 7-9
      assert.are.equal(9, utils.get_char_end_byte(line, 7))
      -- 段 = bytes 10-12
      assert.are.equal(12, utils.get_char_end_byte(line, 10))
      -- 文 = bytes 13-15
      assert.are.equal(15, utils.get_char_end_byte(line, 13))
      -- 本 = bytes 16-18 (last character)
      assert.are.equal(18, utils.get_char_end_byte(line, 16))
    end)

    it("returns correct byte index for mixed ASCII and multi-byte", function()
      local line = "hello 世界" -- "hello " = 6 bytes, 世=3 bytes, 界=3 bytes
      assert.are.equal(1, utils.get_char_end_byte(line, 1)) -- 'h'
      assert.are.equal(6, utils.get_char_end_byte(line, 6)) -- ' '
      assert.are.equal(9, utils.get_char_end_byte(line, 7)) -- '世' (bytes 7-9)
      assert.are.equal(12, utils.get_char_end_byte(line, 10)) -- '界' (bytes 10-12)
    end)

    it("handles byte position beyond line length", function()
      local line = "test"
      assert.are.equal(4, utils.get_char_end_byte(line, 100))
    end)
  end)

  describe("get_visual_selection with multi-byte characters", function()
    it("handles visual selection of multi-byte characters", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "这是一段文本" })
      vim.api.nvim_set_current_buf(buf)

      -- Select all text
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! v$")

      local selection = utils.get_visual_selection()

      -- Should select the entire line
      assert.are.equal(1, selection.start_row)
      assert.are.equal(1, selection.end_row)
      assert.are.equal(1, selection.start_col)
      assert.are.equal(18, selection.end_col) -- Full line is 18 bytes

      -- Verify the text extraction works correctly
      local text =
        utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)
      assert.are.equal("这是一段文本", text)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles partial selection of multi-byte characters", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "这是一段文本" })
      vim.api.nvim_set_current_buf(buf)

      -- Select first two characters (这是)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! v")
      vim.cmd("normal! l") -- Move to second char

      local selection = utils.get_visual_selection()

      -- Should get correct byte positions
      assert.are.equal(1, selection.start_col)
      assert.are.equal(6, selection.end_col) -- End of second char (是)

      local text =
        utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)
      assert.are.equal("这是", text)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles mixed ASCII and multi-byte selection", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello 世界" })
      vim.api.nvim_set_current_buf(buf)

      -- Select entire line
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! v$")

      local selection = utils.get_visual_selection()
      local text =
        utils.get_text_in_range(selection.start_row, selection.start_col, selection.end_row, selection.end_col)
      assert.are.equal("hello 世界", text)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
