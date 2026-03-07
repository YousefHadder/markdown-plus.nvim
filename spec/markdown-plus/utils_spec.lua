---Test suite for markdown-plus.nvim utility functions
---Tests buffer detection, cursor operations, and line manipulation
---@diagnostic disable: undefined-field
local utils = require("markdown-plus.utils")

describe("markdown-plus utils", function()
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

  describe("split_at_cursor", function()
    it("splits ASCII text correctly (character at cursor goes to after)", function()
      local line = "hello world"
      -- Cursor on 'o' of 'hello' (byte 4, 0-indexed)
      local before, after = utils.split_at_cursor(line, 4)
      assert.are.equal("hell", before)
      assert.are.equal("o world", after)
    end)

    it("splits at start of line", function()
      local line = "hello"
      local before, after = utils.split_at_cursor(line, 0)
      assert.are.equal("", before)
      assert.are.equal("hello", after)
    end)

    it("splits at end of line", function()
      local line = "hello"
      -- Cursor at last character 'o' (byte 4, 0-indexed)
      local before, after = utils.split_at_cursor(line, 4)
      assert.are.equal("hell", before)
      assert.are.equal("o", after)
    end)

    it("handles empty line", function()
      local line = ""
      local before, after = utils.split_at_cursor(line, 0)
      assert.are.equal("", before)
      assert.are.equal("", after)
    end)

    it("splits Chinese text correctly at character boundaries", function()
      local line = "你好世界" -- Each Chinese char is 3 bytes
      -- Cursor on '好' (byte 3, 0-indexed = first byte of second char)
      local before, after = utils.split_at_cursor(line, 3)
      assert.are.equal("你", before)
      assert.are.equal("好世界", after)
    end)

    it("splits mixed ASCII and Chinese text correctly", function()
      local line = "hello你好"
      -- Cursor on '你' (byte 5, 0-indexed = first byte of first Chinese char)
      local before, after = utils.split_at_cursor(line, 5)
      assert.are.equal("hello", before)
      assert.are.equal("你好", after)
    end)

    it("handles cursor at last multi-byte character", function()
      local line = "你好"
      -- Cursor on '好' (byte 3, 0-indexed)
      local before, after = utils.split_at_cursor(line, 3)
      assert.are.equal("你", before)
      assert.are.equal("好", after)
    end)

    it("handles cursor position past end of line", function()
      local line = "hello"
      -- Cursor past end
      local before, after = utils.split_at_cursor(line, 100)
      assert.are.equal("hello", before)
      assert.are.equal("", after)
    end)

    it("splits correctly with emoji (4-byte UTF-8)", function()
      local line = "hello😀world"
      -- Cursor on emoji (byte 5, 0-indexed)
      local before, after = utils.split_at_cursor(line, 5)
      assert.are.equal("hello", before)
      assert.are.equal("😀world", after)
    end)
  end)

  describe("split_after_cursor", function()
    it("splits ASCII text correctly (character at cursor goes to before)", function()
      local line = "hello world"
      -- Cursor on 'o' of 'hello' (byte 4, 0-indexed)
      local before, after = utils.split_after_cursor(line, 4)
      assert.are.equal("hello", before)
      assert.are.equal(" world", after)
    end)

    it("splits at start of line", function()
      local line = "hello"
      local before, after = utils.split_after_cursor(line, 0)
      assert.are.equal("h", before)
      assert.are.equal("ello", after)
    end)

    it("splits at end of line", function()
      local line = "hello"
      -- Cursor at last character 'o' (byte 4, 0-indexed)
      local before, after = utils.split_after_cursor(line, 4)
      assert.are.equal("hello", before)
      assert.are.equal("", after)
    end)

    it("handles empty line", function()
      local line = ""
      local before, after = utils.split_after_cursor(line, 0)
      assert.are.equal("", before)
      assert.are.equal("", after)
    end)

    it("splits Chinese text correctly at character boundaries", function()
      local line = "你好世界" -- Each Chinese char is 3 bytes
      -- Cursor on '好' (byte 3, 0-indexed = first byte of second char)
      local before, after = utils.split_after_cursor(line, 3)
      assert.are.equal("你好", before)
      assert.are.equal("世界", after)
    end)

    it("splits mixed ASCII and Chinese text correctly", function()
      local line = "hello你好"
      -- Cursor on '你' (byte 5, 0-indexed = first byte of first Chinese char)
      local before, after = utils.split_after_cursor(line, 5)
      assert.are.equal("hello你", before)
      assert.are.equal("好", after)
    end)

    it("handles cursor at last multi-byte character", function()
      local line = "你好"
      -- Cursor on '好' (byte 3, 0-indexed)
      local before, after = utils.split_after_cursor(line, 3)
      assert.are.equal("你好", before)
      assert.are.equal("", after)
    end)

    it("handles cursor position past end of line", function()
      local line = "hello"
      -- Cursor past end
      local before, after = utils.split_after_cursor(line, 100)
      assert.are.equal("hello", before)
      assert.are.equal("", after)
    end)

    it("splits correctly with emoji (4-byte UTF-8)", function()
      local line = "hello😀world"
      -- Cursor on emoji (byte 5, 0-indexed)
      local before, after = utils.split_after_cursor(line, 5)
      assert.are.equal("hello😀", before)
      assert.are.equal("world", after)
    end)
  end)

  describe("find_pattern_at_cursor", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("finds pattern when cursor is on match", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello [link](url) world" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- cursor on 'link'

      local result = utils.find_pattern_at_cursor("%[.-%]%(.-%)")

      assert.is_not_nil(result)
      assert.are.equal(7, result.start_pos)
      assert.are.equal(17, result.end_pos) -- "[link](url)" is 11 chars, starts at 7, ends at 17
      assert.are.equal("[link](url)", result.text)
      assert.are.equal(1, result.line_num)
    end)

    it("returns nil when cursor is not on any match", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello [link](url) world" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- cursor on 'llo'

      local result = utils.find_pattern_at_cursor("%[.-%]%(.-%)")

      assert.is_nil(result)
    end)

    it("finds correct match when multiple matches exist", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "[first](url1) and [second](url2)" })
      vim.api.nvim_win_set_cursor(0, { 1, 22 }) -- cursor on 'second'

      local result = utils.find_pattern_at_cursor("%[.-%]%(.-%)")

      assert.is_not_nil(result)
      assert.are.equal("[second](url2)", result.text)
    end)

    it("uses extractor function when provided", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "text [link](http://example.com) more" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local extractor = function(match)
        local text, url = match:match("^%[(.-)%]%((.-)%)$")
        if text and url then
          return { type = "inline", text = text, url = url }
        end
        return nil
      end

      local result = utils.find_pattern_at_cursor("%[.-%]%(.-%)", extractor)

      assert.is_not_nil(result)
      assert.are.equal("inline", result.type)
      assert.are.equal("link", result.text)
      assert.are.equal("http://example.com", result.url)
      assert.are.equal(6, result.start_pos) -- auto-added
      assert.are.equal(31, result.end_pos) -- auto-added
    end)

    it("returns nil when extractor returns nil", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "text [link](url) more" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local extractor = function()
        return nil -- always reject
      end

      local result = utils.find_pattern_at_cursor("%[.-%]%(.-%)", extractor)

      assert.is_nil(result)
    end)
  end)

  describe("find_patterns_at_cursor", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("finds first matching pattern", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "text [link](url) more" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local patterns = {
        { pattern = "%[.-%]%[.-%]" }, -- reference link pattern (won't match)
        { pattern = "%[.-%]%(.-%)" }, -- inline link pattern (will match)
      }

      local result = utils.find_patterns_at_cursor(patterns)

      assert.is_not_nil(result)
      assert.are.equal("[link](url)", result.text)
    end)

    it("returns nil when no patterns match", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text without links" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local patterns = {
        { pattern = "%[.-%]%[.-%]" },
        { pattern = "%[.-%]%(.-%)" },
      }

      local result = utils.find_patterns_at_cursor(patterns)

      assert.is_nil(result)
    end)

    it("uses extractors for each pattern", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "text [link][ref] more" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local patterns = {
        {
          pattern = "%[.-%]%(.-%)",
          extractor = function(match)
            local text, url = match:match("^%[(.-)%]%((.-)%)$")
            if text then
              return { type = "inline", text = text, url = url }
            end
          end,
        },
        {
          pattern = "%[.-%]%[.-%]",
          extractor = function(match)
            local text, ref = match:match("^%[(.-)%]%[(.-)%]$")
            if text then
              return { type = "reference", text = text, ref = ref }
            end
          end,
        },
      }

      local result = utils.find_patterns_at_cursor(patterns)

      assert.is_not_nil(result)
      assert.are.equal("reference", result.type)
      assert.are.equal("link", result.text)
      assert.are.equal("ref", result.ref)
    end)
  end)

  describe("replace_in_line", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("replaces range in line with new content", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })

      utils.replace_in_line(1, 7, 11, "universe")

      assert.are.equal("hello universe", utils.get_line(1))
    end)

    it("replaces at start of line", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })

      utils.replace_in_line(1, 1, 5, "hi")

      assert.are.equal("hi world", utils.get_line(1))
    end)

    it("replaces at end of line", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })

      utils.replace_in_line(1, 7, 11, "!")

      assert.are.equal("hello !", utils.get_line(1))
    end)

    it("replaces entire line", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })

      utils.replace_in_line(1, 1, 11, "new content")

      assert.are.equal("new content", utils.get_line(1))
    end)

    it("handles replacement with empty string", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })

      utils.replace_in_line(1, 6, 11, "")

      assert.are.equal("hello", utils.get_line(1))
    end)

    it("works on different line numbers", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line one", "line two", "line three" })

      utils.replace_in_line(2, 6, 8, "2")

      assert.are.equal("line one", utils.get_line(1))
      assert.are.equal("line 2", utils.get_line(2))
      assert.are.equal("line three", utils.get_line(3))
    end)
  end)

  describe("insert_after_cursor", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("inserts content after cursor position", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- on 'o' of 'hello'

      utils.insert_after_cursor(" beautiful")

      assert.are.equal("hello beautiful world", utils.get_line(1))
    end)

    it("moves cursor to end of inserted content", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      utils.insert_after_cursor("!!!")

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(1, cursor[1])
      assert.are.equal(8, cursor[2]) -- after "hello!!!"
    end)

    it("inserts after first character when cursor at start", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "world" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on 'w'

      utils.insert_after_cursor("hello ")

      assert.are.equal("whello orld", utils.get_line(1))
    end)

    it("inserts at end of line", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- on last char

      utils.insert_after_cursor(" world")

      assert.are.equal("hello world", utils.get_line(1))
    end)

    it("handles multi-byte characters correctly", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "你好" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on first char

      utils.insert_after_cursor("世界")

      assert.are.equal("你世界好", utils.get_line(1))
    end)
  end)

  describe("get_single_line_selection", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("returns selection info for single line selection", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world test" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      vim.cmd("normal! viw") -- select 'world'
      vim.cmd("normal! \\<Esc>") -- exit visual mode to set marks

      -- Set marks manually for testing
      vim.fn.setpos("'<", { 0, 1, 7, 0 })
      vim.fn.setpos("'>", { 0, 1, 11, 0 })

      local result = utils.get_single_line_selection("links")

      assert.is_not_nil(result)
      assert.are.equal(1, result.start_row)
      assert.are.equal(7, result.start_col)
      assert.are.equal(11, result.end_col)
      assert.are.equal("world", result.text)
    end)

    it("returns nil for multi-line selection", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line one", "line two" })

      -- Set marks for multi-line selection
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 8, 0 })

      local result = utils.get_single_line_selection("links")

      assert.is_nil(result)
    end)

    it("returns nil for empty selection", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "   " })

      -- Set marks for whitespace-only selection
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 1, 3, 0 })

      local result = utils.get_single_line_selection("images")

      assert.is_nil(result)
    end)

    it("trims whitespace from selection", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello   world   test" })

      -- Set marks to include whitespace
      vim.fn.setpos("'<", { 0, 1, 6, 0 })
      vim.fn.setpos("'>", { 0, 1, 14, 0 })

      local result = utils.get_single_line_selection("links")

      assert.is_not_nil(result)
      assert.are.equal("world", result.text)
    end)

    it("includes line content in result", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "the quick brown fox" })

      vim.fn.setpos("'<", { 0, 1, 5, 0 })
      vim.fn.setpos("'>", { 0, 1, 9, 0 })

      local result = utils.get_single_line_selection("links")

      assert.is_not_nil(result)
      assert.are.equal("the quick brown fox", result.line)
    end)
  end)

  -- Tests use treesitter when available (markdown filetype), with regex fallback
  describe("is_in_code_block", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].filetype = "markdown"
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("returns false when not in a code block", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Header",
        "Some text",
        "- list item",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      assert.is_false(utils.is_in_code_block())
    end)

    it("returns true when inside a backtick code block", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Some text",
        "```rust",
        "fn main() {",
        '    println!("Hello");',
        "}",
        "```",
        "More text",
      })
      vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- inside code block

      assert.is_true(utils.is_in_code_block())
    end)

    it("returns true when inside a tilde code block", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Some text",
        "~~~python",
        "def hello():",
        "    print('Hello')",
        "~~~",
        "More text",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- inside code block

      assert.is_true(utils.is_in_code_block())
    end)

    it("returns false after code block closes", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "```",
        "code",
        "```",
        "not code",
      })
      vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- after code block

      assert.is_false(utils.is_in_code_block())
    end)

    it("returns true on first line inside code block", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "```",
        "first line of code",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      assert.is_true(utils.is_in_code_block())
    end)

    it("returns true on the opening fence line (fence is part of block)", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "text before",
        "```rust",
        "code here",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- on opening fence

      -- The fence line is considered part of the code block
      -- This is acceptable since list handlers won't match fence syntax anyway
      assert.is_true(utils.is_in_code_block())
    end)

    it("handles indented code fences", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "- list item",
        "  ```",
        "  indented code",
        "  ```",
        "- next item",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- inside indented code block

      assert.is_true(utils.is_in_code_block())
    end)

    it("handles multiple code blocks", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "```",
        "first block",
        "```",
        "between blocks",
        "```",
        "second block",
        "```",
      })

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.is_true(utils.is_in_code_block())

      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      assert.is_false(utils.is_in_code_block())

      vim.api.nvim_win_set_cursor(0, { 6, 0 })
      assert.is_true(utils.is_in_code_block())
    end)

    it("handles unclosed code block", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "```",
        "unclosed code",
        "more code",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      assert.is_true(utils.is_in_code_block())
    end)
  end)

  describe("get_lines_in_range", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
    end)

    after_each(function()
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("returns the correct lines for a valid range", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })
      local lines = utils.get_lines_in_range(1, 2)
      assert.are.same({ "First line", "Second line" }, lines)
    end)

    it("returns all lines when range covers full buffer", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Line 1",
        "Line 2",
        "Line 3",
      })
      local lines = utils.get_lines_in_range(1, 3)
      assert.are.same({ "Line 1", "Line 2", "Line 3" }, lines)
    end)

    it("returns single line for equal start and end", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Only line",
      })
      local lines = utils.get_lines_in_range(1, 1)
      assert.are.same({ "Only line" }, lines)
    end)

    it("returns an empty list for an out-of-bounds range", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "First line" })
      local lines = utils.get_lines_in_range(2, 3)
      assert.are.same({}, lines)
    end)
  end)

  describe("get_code_block_lines", function()
    it("returns empty table for lines without code blocks", function()
      local lines = {
        "# Header",
        "Some text",
        "More text",
      }
      local result = utils.get_code_block_lines(lines)
      assert.are.same({}, result)
    end)

    it("marks backtick code block lines", function()
      local lines = {
        "Before",
        "```",
        "code line 1",
        "code line 2",
        "```",
        "After",
      }
      local result = utils.get_code_block_lines(lines)
      assert.is_nil(result[1])
      assert.is_true(result[2]) -- opening fence
      assert.is_true(result[3])
      assert.is_true(result[4])
      assert.is_true(result[5]) -- closing fence
      assert.is_nil(result[6])
    end)

    it("marks tilde code block lines", function()
      local lines = {
        "Before",
        "~~~",
        "code",
        "~~~",
        "After",
      }
      local result = utils.get_code_block_lines(lines)
      assert.is_nil(result[1])
      assert.is_true(result[2])
      assert.is_true(result[3])
      assert.is_true(result[4])
      assert.is_nil(result[5])
    end)

    it("handles indented code fences", function()
      local lines = {
        "  ```lua",
        "  local x = 1",
        "  ```",
      }
      local result = utils.get_code_block_lines(lines)
      assert.is_true(result[1])
      assert.is_true(result[2])
      assert.is_true(result[3])
    end)

    it("handles unclosed code block", function()
      local lines = {
        "```",
        "unclosed code",
        "still code",
      }
      local result = utils.get_code_block_lines(lines)
      assert.is_true(result[1])
      assert.is_true(result[2])
      assert.is_true(result[3])
    end)

    it("handles multiple code blocks", function()
      local lines = {
        "Text",
        "```",
        "block 1",
        "```",
        "Between",
        "~~~",
        "block 2",
        "~~~",
        "End",
      }
      local result = utils.get_code_block_lines(lines)
      assert.is_nil(result[1])
      assert.is_true(result[2])
      assert.is_true(result[3])
      assert.is_true(result[4])
      assert.is_nil(result[5])
      assert.is_true(result[6])
      assert.is_true(result[7])
      assert.is_true(result[8])
      assert.is_nil(result[9])
    end)

    it("handles empty input", function()
      local result = utils.get_code_block_lines({})
      assert.are.same({}, result)
    end)
  end)

  describe("build_markdown_link", function()
    it("builds simple link without title", function()
      assert.are.equal("[text](https://example.com)", utils.build_markdown_link("text", "https://example.com"))
    end)

    it("builds link with title", function()
      assert.are.equal(
        '[text](https://example.com "My Title")',
        utils.build_markdown_link("text", "https://example.com", "My Title")
      )
    end)

    it("omits title when nil", function()
      assert.are.equal("[text](url)", utils.build_markdown_link("text", "url", nil))
    end)

    it("omits title when empty string", function()
      assert.are.equal("[text](url)", utils.build_markdown_link("text", "url", ""))
    end)

    it("handles empty text", function()
      assert.are.equal("[](url)", utils.build_markdown_link("", "url"))
    end)

    it("handles special characters in text and url", function()
      assert.are.equal(
        "[hello world](https://example.com/path?q=1&r=2)",
        utils.build_markdown_link("hello world", "https://example.com/path?q=1&r=2")
      )
    end)
  end)

  describe("build_markdown_image", function()
    it("builds simple image without title", function()
      assert.are.equal("![alt](image.png)", utils.build_markdown_image("alt", "image.png"))
    end)

    it("builds image with title", function()
      assert.are.equal('![alt](image.png "Photo")', utils.build_markdown_image("alt", "image.png", "Photo"))
    end)

    it("omits title when nil", function()
      assert.are.equal("![alt](url)", utils.build_markdown_image("alt", "url", nil))
    end)

    it("omits title when empty string", function()
      assert.are.equal("![alt](url)", utils.build_markdown_image("alt", "url", ""))
    end)

    it("handles empty alt text", function()
      assert.are.equal("![](url)", utils.build_markdown_image("", "url"))
    end)
  end)
end)
