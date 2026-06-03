---Test suite for markdown-plus.nvim list parser (additional cases)
---Tests letter lists, next/previous markers, and checkbox parsing
---@diagnostic disable: undefined-field
local parser = require("markdown-plus.list.parser")

describe("markdown-plus list parser", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  ---Helper to set a line in the buffer and parse it
  ---@param line string
  ---@param row? number
  ---@return markdown-plus.ListInfo|nil
  local function set_and_parse(line, row)
    row = row or 1
    local line_count = vim.api.nvim_buf_line_count(0)
    if row > line_count then
      local padding = {}
      for _ = 1, row - line_count do
        table.insert(padding, "")
      end
      vim.api.nvim_buf_set_lines(0, line_count, line_count, false, padding)
    end
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line })
    return parser.parse_list_line(line, row)
  end

  describe("letter list parsing", function()
    it("parses lowercase letter list (a.)", function()
      local info = set_and_parse("a. Item")
      assert.is_not_nil(info)
      assert.are.equal("letter_lower", info.type)
      assert.are.equal("a.", info.marker)
    end)

    it("parses uppercase letter list (A.)", function()
      local info = set_and_parse("A. Item")
      assert.is_not_nil(info)
      assert.are.equal("letter_upper", info.type)
    end)

    it("parses letter paren list (a))", function()
      local info = set_and_parse("a) Item")
      assert.is_not_nil(info)
      assert.are.equal("letter_lower_paren", info.type)
    end)
  end)

  describe("get_next_marker", function()
    it("increments ordered list marker", function()
      local info = set_and_parse("1. first")
      assert.is_not_nil(info)
      local next = parser.get_next_marker(info)
      assert.are.equal("2.", next)
    end)

    it("increments letter list marker", function()
      local info = set_and_parse("a. first")
      assert.is_not_nil(info)
      local next = parser.get_next_marker(info)
      assert.are.equal("b.", next)
    end)
  end)

  describe("get_previous_marker", function()
    it("returns decremented marker for ordered list", function()
      -- Place "2. second" on row 1 with "3. third" on row 2 to test previous
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "2. second", "3. third" })
      local info = parser.parse_list_line("3. third", 2)
      assert.is_not_nil(info)
      local prev = parser.get_previous_marker(info, 2)
      -- Should find prev item "2. second" and return incremented "3."
      assert.are.equal("3.", prev)
    end)
  end)

  describe("checkbox parsing", function()
    it("parses checkbox in unordered list", function()
      local info = set_and_parse("- [x] Done")
      assert.is_not_nil(info)
      assert.are.equal("x", info.checkbox)
    end)

    it("parses checkbox in ordered list", function()
      local info = set_and_parse("1. [ ] Todo")
      assert.is_not_nil(info)
      assert.are.equal(" ", info.checkbox)
    end)
  end)

  describe("regex fallback and empty markers", function()
    it("parses letter lists via regex fallback (treesitter has no letter markers)", function()
      local info = set_and_parse("c) Item")
      assert.is_not_nil(info)
      assert.are.equal("letter_lower_paren", info.type)
      assert.are.equal("c)", info.marker)
    end)

    it("parses an empty marker at EOL by default", function()
      local info = set_and_parse("1.")
      assert.is_not_nil(info)
      assert.are.equal("ordered", info.type)
      assert.are.equal("1.", info.marker)
    end)

    it("skips empty markers when skip_empty_patterns is set", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1." })
      local info = parser.parse_list_line("1.", nil, { skip_empty_patterns = true })
      assert.is_nil(info)
    end)

    it("still parses non-empty markers when skip_empty_patterns is set", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1. content" })
      local info = parser.parse_list_line("1. content", nil, { skip_empty_patterns = true })
      assert.is_not_nil(info)
      assert.are.equal("ordered", info.type)
    end)

    it("returns nil for non-list lines", function()
      assert.is_nil(parser.parse_list_line("just text", 1))
    end)

    it("returns nil when line is nil", function()
      assert.is_nil(parser.parse_list_line(nil))
    end)
  end)

  describe("is_empty_list_item", function()
    it("returns true for a marker with no content", function()
      local info = set_and_parse("- ")
      assert.is_not_nil(info)
      assert.is_true(parser.is_empty_list_item("- ", info))
    end)

    it("returns false when content follows the marker", function()
      local info = set_and_parse("- item")
      assert.is_not_nil(info)
      assert.is_false(parser.is_empty_list_item("- item", info))
    end)

    it("returns false for nil inputs", function()
      assert.is_false(parser.is_empty_list_item(nil, nil))
    end)
  end)

  describe("backwards-compatible re-exports", function()
    it("re-exports marker utilities from the markers module", function()
      assert.is_function(parser.index_to_letter)
      assert.is_function(parser.next_letter)
      assert.is_function(parser.get_next_marker)
      assert.is_function(parser.get_previous_marker)
      assert.are.equal("b", parser.next_letter("a", false))
      assert.are.equal("a", parser.index_to_letter(1, false))
    end)

    it("re-exports the patterns table", function()
      assert.is_table(parser.patterns)
      assert.is_string(parser.patterns.unordered)
    end)
  end)
end)
