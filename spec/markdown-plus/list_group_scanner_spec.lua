---Test suite for markdown-plus.nvim list group scanner
---Tests list breaking line detection and list group discovery
---@diagnostic disable: undefined-field
local group_scanner = require("markdown-plus.list.group_scanner")

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

  describe("set_html_awareness", function()
    it("toggles html awareness without error", function()
      -- Should not error
      group_scanner.set_html_awareness(false)
      group_scanner.set_html_awareness(true)
    end)
  end)
end)
