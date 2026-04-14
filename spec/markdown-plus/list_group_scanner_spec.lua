---Test suite for markdown-plus.nvim list group scanner
---Tests list breaking line detection and list group discovery
---@diagnostic disable: undefined-field
local group_scanner = require("markdown-plus.list.group_scanner")
local parser = require("markdown-plus.list.parser")

describe("markdown-plus list group scanner", function()
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

  describe("is_list_breaking_line", function()
    it("treats blank lines as list-breaking", function()
      assert.is_true(group_scanner.is_list_breaking_line(""))
      assert.is_true(group_scanner.is_list_breaking_line("   "))
    end)

    it("treats nil as list-breaking", function()
      assert.is_true(group_scanner.is_list_breaking_line(nil))
    end)

    it("treats headers as list-breaking", function()
      assert.is_true(group_scanner.is_list_breaking_line("# Header"))
      assert.is_true(group_scanner.is_list_breaking_line("## Sub-header"))
    end)

    it("treats paragraphs as list-breaking", function()
      assert.is_true(group_scanner.is_list_breaking_line("Some paragraph text"))
    end)

    it("does not treat list items as list-breaking", function()
      assert.is_false(group_scanner.is_list_breaking_line("- unordered item"))
      assert.is_false(group_scanner.is_list_breaking_line("1. ordered item"))
      assert.is_false(group_scanner.is_list_breaking_line("  * nested item"))
    end)

    it("does not treat continuation lines as list-breaking when context given", function()
      local lines = {
        "1. First item",
        "   continued here",
      }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      -- Line 2 is a continuation of line 1 (indented to content start col)
      assert.is_false(group_scanner.is_list_breaking_line(lines[2], 2, lines))
    end)

    it("treats code fence lines as list-breaking", function()
      assert.is_true(group_scanner.is_list_breaking_line("```lua"))
      assert.is_true(group_scanner.is_list_breaking_line("~~~"))
    end)
  end)

  describe("find_list_groups", function()
    it("finds a basic ordered list as a single group", function()
      local lines = {
        "1. First",
        "2. Second",
        "3. Third",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(1, #groups)
      assert.are.equal(3, #groups[1].items)
      assert.are.equal(0, groups[1].indent)
      assert.are.equal("ordered", groups[1].list_type)
    end)

    it("separates nested ordered lists into distinct groups", function()
      local lines = {
        "1. A",
        "    1. B",
        "    2. C",
        "2. D",
      }
      local groups = group_scanner.find_list_groups(lines)

      -- Top-level group: lines 1, 4
      assert.are.equal(2, #groups[1].items)
      assert.are.equal(0, groups[1].indent)

      -- Nested group: lines 2, 3
      local nested = groups[2]
      assert.are.equal(4, nested.indent)
      assert.are.equal(2, #nested.items)
    end)

    it("excludes lines inside fenced code blocks", function()
      local lines = {
        "1. First",
        "```",
        "2. Not a list item",
        "```",
        "2. Second",
      }
      local groups = group_scanner.find_list_groups(lines)
      -- The code block separates the two items; content inside is skipped
      -- Non-indented code block breaks continuity, so 2 separate groups
      assert.are.equal(2, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal(1, #groups[2].items)
    end)

    it("finds multiple separate groups split by blank lines", function()
      local lines = {
        "1. First",
        "2. Second",
        "",
        "1. Alpha",
        "2. Beta",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(2, #groups)
      assert.are.equal(2, #groups[1].items)
      assert.are.equal(2, #groups[2].items)
    end)

    it("returns empty table for empty buffer", function()
      local groups = group_scanner.find_list_groups({})
      assert.are.equal(0, #groups)
    end)

    it("returns empty table for buffer with no lists", function()
      local lines = {
        "# Header",
        "",
        "Just a paragraph.",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(0, #groups)
    end)

    it("ignores unordered list items (only finds orderable groups)", function()
      local lines = {
        "- First",
        "- Second",
        "- Third",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(0, #groups)
    end)

    it("handles mixed ordered and unordered items", function()
      local lines = {
        "1. First",
        "2. Second",
        "- Unordered",
        "3. Third",
      }
      local groups = group_scanner.find_list_groups(lines)
      -- Unordered item at same indent breaks the ordered group
      assert.are.equal(2, #groups)
      assert.are.equal(2, #groups[1].items) -- 1. First, 2. Second
      assert.are.equal(1, #groups[2].items) -- 3. Third
    end)
  end)

  describe("empty marker exclusion from groups", function()
    it("does not include standalone empty alpha marker in any group", function()
      local lines = {
        "E.",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(0, #groups)
    end)

    it("does not include standalone empty numeric marker in any group", function()
      local lines = {
        "1.",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(0, #groups)
    end)

    it("does not include standalone empty unordered marker in any group", function()
      local lines = {
        "-",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(0, #groups)
    end)

    it("includes marker with trailing space and content in groups", function()
      local lines = {
        "E. text",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(1, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal("letter_upper", groups[1].list_type)
    end)

    it("groups multi-item alpha list correctly", function()
      local lines = {
        "A. first",
        "B. second",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(1, #groups)
      assert.are.equal(2, #groups[1].items)
      assert.are.equal("letter_upper", groups[1].list_type)
    end)

    it("treats empty marker as list-breaking between real list items", function()
      local lines = {
        "A. first",
        "E.",
        "B. third",
      }
      local groups = group_scanner.find_list_groups(lines)
      -- E. without trailing space is not a list item and breaks the group
      assert.are.equal(2, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal(1, #groups[2].items)
    end)

    it("treats empty numeric marker as list-breaking", function()
      local lines = {
        "1. first",
        "2.",
        "3. third",
      }
      local groups = group_scanner.find_list_groups(lines)
      -- 2. without trailing space breaks the group
      assert.are.equal(2, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal(1, #groups[2].items)
    end)

    it("treats empty paren marker as list-breaking", function()
      local lines = {
        "1) first",
        "2)",
        "3) third",
      }
      local groups = group_scanner.find_list_groups(lines)
      assert.are.equal(2, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal(1, #groups[2].items)
    end)

    it("still recognizes empty markers via parse_list_line without opts", function()
      -- The enter handler path calls parse_list_line without opts,
      -- so empty markers should still parse for break-out-of-list behavior
      local info = parser.parse_list_line("B.", nil)
      assert.is_not_nil(info)
      assert.are.equal("letter_upper", info.type)
    end)

    it("does not recognize empty markers when skip_empty_patterns is set", function()
      local info = parser.parse_list_line("B.", nil, { skip_empty_patterns = true })
      assert.is_nil(info)
    end)

    it("is_list_breaking_line treats empty markers as breaking", function()
      -- Empty markers without trailing space should break list continuity
      assert.is_true(group_scanner.is_list_breaking_line("E."))
      assert.is_true(group_scanner.is_list_breaking_line("1."))
      assert.is_true(group_scanner.is_list_breaking_line("-"))
    end)
  end)

  describe("set_html_awareness", function()
    it("toggles html awareness without error", function()
      -- Should not error
      group_scanner.set_html_awareness(false)
      group_scanner.set_html_awareness(true)
    end)
  end)
end)
