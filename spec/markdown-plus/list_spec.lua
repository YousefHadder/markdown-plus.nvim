---Test suite for markdown-plus.nvim list management
---Tests list parsing, empty list detection, and list continuation
---@diagnostic disable: undefined-field
local list = require("markdown-plus.list")

describe("markdown-plus list management", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_set_current_buf(buf)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("parse_list_line", function()
    it("parses unordered list items", function()
      local info = list.parse_list_line("- List item")
      assert.is_not_nil(info)
      assert.are.equal("unordered", info.type)
      assert.are.equal("-", info.marker)
    end)

    it("parses ordered list items", function()
      local info = list.parse_list_line("1. List item")
      assert.is_not_nil(info)
      assert.are.equal("ordered", info.type)
    end)

    it("parses parenthesized ordered list items", function()
      local info = list.parse_list_line("1) List item")
      assert.is_not_nil(info)
      assert.are.equal("ordered_paren", info.type)
      assert.are.equal("1)", info.marker)
    end)

    it("parses parenthesized lowercase letter list items", function()
      local info = list.parse_list_line("a) List item")
      assert.is_not_nil(info)
      assert.are.equal("letter_lower_paren", info.type)
      assert.are.equal("a)", info.marker)
    end)

    it("parses parenthesized uppercase letter list items", function()
      local info = list.parse_list_line("A) List item")
      assert.is_not_nil(info)
      assert.are.equal("letter_upper_paren", info.type)
      assert.are.equal("A)", info.marker)
    end)

    it("parses task list items", function()
      local info = list.parse_list_line("- [ ] Unchecked task")
      assert.is_not_nil(info)
      assert.is_not_nil(info.checkbox)
    end)

    it("parses parenthesized ordered task list items", function()
      local info = list.parse_list_line("1) [ ] Unchecked task")
      assert.is_not_nil(info)
      assert.are.equal("ordered_paren", info.type)
      assert.is_not_nil(info.checkbox)
    end)

    it("parses letter_lower list items", function()
      local result = list.parse_list_line("  a. item")
      assert.is_not_nil(result)
      assert.equal("letter_lower", result.type)
      assert.equal("a.", result.marker)
      assert.equal("  ", result.indent)
    end)

    it("parses letter_upper list items", function()
      local result = list.parse_list_line("  A. item")
      assert.is_not_nil(result)
      assert.equal("letter_upper", result.type)
      assert.equal("A.", result.marker)
      assert.equal("  ", result.indent)
    end)

    it("returns nil for non-list lines", function()
      local info = list.parse_list_line("Not a list")
      assert.is_nil(info)
    end)
  end)

  describe("is_empty_list_item", function()
    it("detects empty list items", function()
      local info = list.parse_list_line("- ")
      local is_empty = list.is_empty_list_item("- ", info)
      assert.is_true(is_empty)
    end)

    it("detects non-empty list items", function()
      local info = list.parse_list_line("- Content")
      local is_empty = list.is_empty_list_item("- Content", info)
      assert.is_false(is_empty)
    end)
  end)

  describe("index_to_letter", function()
    it("converts indices to lowercase letters", function()
      assert.are.equal("a", list.index_to_letter(1, false))
      assert.are.equal("b", list.index_to_letter(2, false))
      assert.are.equal("z", list.index_to_letter(26, false))
    end)

    it("converts indices to uppercase letters", function()
      assert.are.equal("A", list.index_to_letter(1, true))
      assert.are.equal("B", list.index_to_letter(2, true))
      assert.are.equal("Z", list.index_to_letter(26, true))
    end)
  end)

  describe("find_list_groups", function()
    it("finds simple ordered list as single group", function()
      local lines = {
        "1. First",
        "2. Second",
        "3. Third",
      }
      local groups = list.find_list_groups(lines)
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
        "    3. E",
        "    4. F",
        "3. G",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 3 groups:
      -- 1. Top level (lines 1, 4, 7: A, D, G) - continuous group
      -- 2. First nested (lines 2, 3: B, C)
      -- 3. Second nested (lines 5, 6: E, F) - separated from first nested
      assert.are.equal(3, #groups)

      -- Verify first group (top level - all items)
      assert.are.equal(0, groups[1].indent)
      assert.are.equal(3, #groups[1].items)
      assert.are.equal(1, groups[1].items[1].line_num)
      assert.are.equal(4, groups[1].items[2].line_num)
      assert.are.equal(7, groups[1].items[3].line_num)

      -- Verify second group (first nested)
      assert.are.equal(4, groups[2].indent)
      assert.are.equal(2, #groups[2].items)
      assert.are.equal(2, groups[2].items[1].line_num)
      assert.are.equal(3, groups[2].items[2].line_num)

      -- Verify third group (second nested - separate from first)
      assert.are.equal(4, groups[3].indent)
      assert.are.equal(2, #groups[3].items)
      assert.are.equal(5, groups[3].items[1].line_num)
      assert.are.equal(6, groups[3].items[2].line_num)
    end)

    it("handles nested letter lists correctly", function()
      local lines = {
        "a. First",
        "    a. Nested 1",
        "    b. Nested 2",
        "b. Second",
        "    c. Nested 3",
        "    d. Nested 4",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 3 groups (top-level continuous, then two nested groups)
      assert.are.equal(3, #groups)

      -- Verify groups are separated correctly
      assert.are.equal("letter_lower", groups[1].list_type)
      assert.are.equal(0, groups[1].indent)
      assert.are.equal(2, #groups[1].items) -- a. First, b. Second
      assert.are.equal("letter_lower", groups[2].list_type)
      assert.are.equal(4, groups[2].indent)
      assert.are.equal(2, #groups[2].items) -- First nested group
      assert.are.equal(2, #groups[3].items) -- Second nested group
    end)

    it("handles three-level nesting", function()
      local lines = {
        "1. Level 1",
        "    1. Level 2",
        "        1. Level 3",
        "        2. Level 3",
        "    2. Level 2",
        "2. Level 1",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 3 groups (L1 continuous, L2 continuous, L3)
      assert.are.equal(3, #groups)
      assert.are.equal(0, groups[1].indent)
      assert.are.equal(2, #groups[1].items) -- Both L1 items
      assert.are.equal(4, groups[2].indent)
      assert.are.equal(2, #groups[2].items) -- Both L2 items
      assert.are.equal(8, groups[3].indent)
      assert.are.equal(2, #groups[3].items) -- Both L3 items
    end)

    it("handles parenthesized ordered lists", function()
      local lines = {
        "1) A",
        "    1) B",
        "    2) C",
        "2) D",
        "    3) E",
        "    4) F",
      }
      local groups = list.find_list_groups(lines)

      assert.are.equal(3, #groups)
      assert.are.equal("ordered_paren", groups[1].list_type)
      assert.are.equal(2, #groups[1].items) -- Top level: A, D
      assert.are.equal("ordered_paren", groups[2].list_type)
      assert.are.equal(2, #groups[2].items) -- First nested: B, C
      assert.are.equal("ordered_paren", groups[3].list_type)
      assert.are.equal(2, #groups[3].items) -- Second nested: E, F
    end)

    it("separates groups when encountering non-list content", function()
      local lines = {
        "1. First",
        "2. Second",
        "",
        "Some text",
        "",
        "1. Third",
        "2. Fourth",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 2 groups separated by non-list content
      assert.are.equal(2, #groups)
      assert.are.equal(2, #groups[1].items)
      assert.are.equal(2, #groups[2].items)
    end)

    it("separates groups when encountering blank lines", function()
      local lines = {
        "1. A",
        "2. B",
        "",
        "3. C",
        "4. D",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 2 groups separated by blank line
      assert.are.equal(2, #groups)
      assert.are.equal(2, #groups[1].items)
      assert.are.equal(1, groups[1].items[1].line_num)
      assert.are.equal(2, groups[1].items[2].line_num)
      assert.are.equal(2, #groups[2].items)
      assert.are.equal(4, groups[2].items[1].line_num)
      assert.are.equal(5, groups[2].items[2].line_num)
    end)

    it("handles multiple blank lines between lists", function()
      local lines = {
        "1. First",
        "",
        "",
        "2. Second",
      }
      local groups = list.find_list_groups(lines)

      -- Should have 2 groups
      assert.are.equal(2, #groups)
      assert.are.equal(1, #groups[1].items)
      assert.are.equal(1, #groups[2].items)
    end)

    it("handles blank lines in nested lists", function()
      local lines = {
        "1. A",
        "    1. B",
        "",
        "    2. C",
        "2. D",
      }
      local groups = list.find_list_groups(lines)

      -- Blank line terminates all active groups (at all indentation levels), resulting in 4 separate groups
      assert.are.equal(4, #groups)
      assert.are.equal(0, groups[1].indent)
      assert.are.equal(1, #groups[1].items) -- A only
      assert.are.equal(4, groups[2].indent)
      assert.are.equal(1, #groups[2].items) -- B only
      assert.are.equal(4, groups[3].indent)
      assert.are.equal(1, #groups[3].items) -- C only
      assert.are.equal(0, groups[4].indent)
      assert.are.equal(1, #groups[4].items) -- D only
    end)
  end)

  describe("renumber_list_group", function()
    it("renumbers simple ordered list correctly", function()
      local group = {
        indent = 0,
        list_type = "ordered",
        items = {
          { line_num = 1, indent = "", checkbox = nil, content = "First", original_line = "3. First" },
          { line_num = 2, indent = "", checkbox = nil, content = "Second", original_line = "7. Second" },
          { line_num = 3, indent = "", checkbox = nil, content = "Third", original_line = "1. Third" },
        },
      }

      local changes = list.renumber_list_group(group)
      assert.is_not_nil(changes)
      assert.are.equal(3, #changes)
      assert.are.equal("1. First", changes[1].new_line)
      assert.are.equal("2. Second", changes[2].new_line)
      assert.are.equal("3. Third", changes[3].new_line)
    end)

    it("renumbers letter lists correctly", function()
      local group = {
        indent = 4,
        list_type = "letter_lower",
        items = {
          { line_num = 1, indent = "    ", checkbox = nil, content = "First", original_line = "    c. First" },
          { line_num = 2, indent = "    ", checkbox = nil, content = "Second", original_line = "    d. Second" },
        },
      }

      local changes = list.renumber_list_group(group)
      assert.is_not_nil(changes)
      assert.are.equal(2, #changes)
      assert.are.equal("    a. First", changes[1].new_line)
      assert.are.equal("    b. Second", changes[2].new_line)
    end)

    it("preserves checkboxes when renumbering", function()
      local group = {
        indent = 0,
        list_type = "ordered",
        items = {
          { line_num = 1, indent = "", checkbox = "x", content = "Done", original_line = "3. [x] Done" },
          { line_num = 2, indent = "", checkbox = " ", content = "Todo", original_line = "7. [ ] Todo" },
        },
      }

      local changes = list.renumber_list_group(group)
      assert.is_not_nil(changes)
      assert.are.equal(2, #changes)
      assert.are.equal("1. [x] Done", changes[1].new_line)
      assert.are.equal("2. [ ] Todo", changes[2].new_line)
    end)
  end)

  describe("renumber_ordered_lists integration", function()
    it("renumbers nested ordered lists correctly", function()
      local lines = {
        "1. A",
        "    1. B",
        "    2. C",
        "2. D",
        "    3. E",
        "    4. F",
        "3. G",
      }

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      list.renumber_ordered_lists()

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1. A", result[1])
      assert.are.equal("    1. B", result[2])
      assert.are.equal("    2. C", result[3])
      assert.are.equal("2. D", result[4])
      assert.are.equal("    1. E", result[5]) -- Should restart at 1
      assert.are.equal("    2. F", result[6]) -- Should be 2
      assert.are.equal("3. G", result[7])
    end)

    it("renumbers nested letter lists correctly", function()
      local lines = {
        "a. First",
        "    c. Nested 1",
        "    d. Nested 2",
        "b. Second",
        "    e. Nested 3",
        "    f. Nested 4",
      }

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      list.renumber_ordered_lists()

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("a. First", result[1])
      assert.are.equal("    a. Nested 1", result[2])
      assert.are.equal("    b. Nested 2", result[3])
      assert.are.equal("b. Second", result[4])
      assert.are.equal("    a. Nested 3", result[5]) -- Should restart at a
      assert.are.equal("    b. Nested 4", result[6]) -- Should be b
    end)

    it("handles three-level nesting", function()
      local lines = {
        "1. Level 1",
        "    5. Level 2",
        "        7. Level 3",
        "        8. Level 3",
        "    6. Level 2",
        "2. Level 1",
      }

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      list.renumber_ordered_lists()

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1. Level 1", result[1])
      assert.are.equal("    1. Level 2", result[2])
      assert.are.equal("        1. Level 3", result[3])
      assert.are.equal("        2. Level 3", result[4])
      assert.are.equal("    2. Level 2", result[5])
      assert.are.equal("2. Level 1", result[6])
    end)

    it("separates lists with blank lines and renumbers each from 1", function()
      local lines = {
        "1. A",
        "2. B",
        "",
        "3. C",
        "4. D",
      }

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      list.renumber_ordered_lists()

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1. A", result[1])
      assert.are.equal("2. B", result[2])
      assert.are.equal("", result[3])
      assert.are.equal("1. C", result[4]) -- Should restart at 1
      assert.are.equal("2. D", result[5])
    end)

    it("handles letter lists separated by blank lines", function()
      local lines = {
        "a. First",
        "b. Second",
        "",
        "c. Third",
      }

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      list.renumber_ordered_lists()

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("a. First", result[1])
      assert.are.equal("b. Second", result[2])
      assert.are.equal("", result[3])
      assert.are.equal("a. Third", result[4]) -- Should restart at a
    end)
  end)

  describe("checkbox management", function()
    describe("add_checkbox_to_line", function()
      it("adds checkbox to unordered list item", function()
        local line = "- Item without checkbox"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("- [ ] Item without checkbox", result)
      end)

      it("adds checkbox to ordered list item", function()
        local line = "1. First item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("1. [ ] First item", result)
      end)

      it("adds checkbox to letter list item (lowercase)", function()
        local line = "a. Letter item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("a. [ ] Letter item", result)
      end)

      it("adds checkbox to letter list item (uppercase)", function()
        local line = "A. Letter item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("A. [ ] Letter item", result)
      end)

      it("adds checkbox to parenthesized ordered list", function()
        local line = "1) Parenthesized item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("1) [ ] Parenthesized item", result)
      end)

      it("adds checkbox to parenthesized letter list (lowercase)", function()
        local line = "a) Parenthesized letter"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("a) [ ] Parenthesized letter", result)
      end)

      it("adds checkbox to parenthesized letter list (uppercase)", function()
        local line = "A) Parenthesized letter"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("A) [ ] Parenthesized letter", result)
      end)

      it("adds checkbox to indented list item", function()
        local line = "  - Indented item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("  - [ ] Indented item", result)
      end)

      it("adds checkbox to list item with + marker", function()
        local line = "+ Plus marker item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("+ [ ] Plus marker item", result)
      end)

      it("adds checkbox to list item with * marker", function()
        local line = "* Star marker item"
        local list_info = list.parse_list_line(line)
        local result = list.add_checkbox_to_line(line, list_info)
        assert.are.equal("* [ ] Star marker item", result)
      end)
    end)

    describe("replace_checkbox_state", function()
      it("toggles unchecked to checked", function()
        local line = "- [ ] Unchecked item"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("- [x] Unchecked item", result)
      end)

      it("toggles checked to unchecked", function()
        local line = "- [x] Checked item"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("- [ ] Checked item", result)
      end)

      it("toggles uppercase X to unchecked", function()
        local line = "- [X] Checked with uppercase"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("- [ ] Checked with uppercase", result)
      end)

      it("toggles ordered list checkbox", function()
        local line = "1. [ ] Ordered unchecked"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("1. [x] Ordered unchecked", result)
      end)

      it("toggles letter list checkbox", function()
        local line = "a. [x] Letter checked"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("a. [ ] Letter checked", result)
      end)

      it("toggles indented checkbox", function()
        local line = "  - [x] Indented checked"
        local list_info = list.parse_list_line(line)
        local result = list.replace_checkbox_state(line, list_info)
        assert.are.equal("  - [ ] Indented checked", result)
      end)
    end)

    describe("toggle_checkbox_in_line", function()
      it("adds checkbox when none exists", function()
        local line = "- Regular item"
        local list_info = list.parse_list_line(line)
        local result = list.toggle_checkbox_in_line(line, list_info)
        assert.are.equal("- [ ] Regular item", result)
      end)

      it("toggles unchecked to checked", function()
        local line = "- [ ] Todo item"
        local list_info = list.parse_list_line(line)
        local result = list.toggle_checkbox_in_line(line, list_info)
        assert.are.equal("- [x] Todo item", result)
      end)

      it("toggles checked to unchecked", function()
        local line = "- [x] Completed item"
        local list_info = list.parse_list_line(line)
        local result = list.toggle_checkbox_in_line(line, list_info)
        assert.are.equal("- [ ] Completed item", result)
      end)

      it("works with ordered lists", function()
        local line = "1. Regular ordered"
        local list_info = list.parse_list_line(line)
        local result = list.toggle_checkbox_in_line(line, list_info)
        assert.are.equal("1. [ ] Regular ordered", result)
      end)

      it("works with letter lists", function()
        local line = "a. Letter item"
        local list_info = list.parse_list_line(line)
        local result = list.toggle_checkbox_in_line(line, list_info)
        assert.are.equal("a. [ ] Letter item", result)
      end)
    end)

    describe("toggle_checkbox_on_line", function()
      it("adds checkbox to list item without one", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- Item without checkbox" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [ ] Item without checkbox", lines[1])
      end)

      it("toggles checkbox from unchecked to checked", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [ ] Unchecked item" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [x] Unchecked item", lines[1])
      end)

      it("toggles checkbox from checked to unchecked", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [x] Checked item" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [ ] Checked item", lines[1])
      end)

      it("does nothing on non-list lines", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Regular paragraph text" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("Regular paragraph text", lines[1])
      end)

      it("does nothing on empty lines", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("", lines[1])
      end)

      it("works with ordered lists", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. First item" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("1. [ ] First item", lines[1])
      end)

      it("works with indented lists", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  - Indented item" })
        list.toggle_checkbox_on_line(1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("  - [ ] Indented item", lines[1])
      end)
    end)

    describe("toggle_checkbox_range", function()
      it("adds checkboxes to multiple list items", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "- First item",
          "- Second item",
          "- Third item",
        })
        -- Enter visual mode and select lines 1-2
        vim.cmd("normal! ggV")
        vim.cmd("normal! j")
        list.toggle_checkbox_range()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [ ] First item", lines[1])
        assert.are.equal("- [ ] Second item", lines[2])
        assert.are.equal("- Third item", lines[3])
      end)

      it("toggles checkboxes in multiple list items", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "- [ ] Unchecked",
          "- [x] Checked",
          "- Regular",
        })
        -- Enter visual mode and select all 3 lines
        vim.cmd("normal! ggV")
        vim.cmd("normal! 2j")
        list.toggle_checkbox_range()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [x] Unchecked", lines[1])
        assert.are.equal("- [ ] Checked", lines[2])
        assert.are.equal("- [ ] Regular", lines[3])
      end)
    end)

    describe("toggle_checkbox_line (normal mode)", function()
      it("toggles checkbox on current line", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [ ] Todo" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        list.toggle_checkbox_line()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal("- [x] Todo", lines[1])
      end)
    end)

    describe("toggle_checkbox_insert (insert mode)", function()
      it("toggles checkbox and maintains cursor position", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [ ] Todo item" })
        vim.api.nvim_win_set_cursor(0, { 1, 10 })
        local initial_col = vim.api.nvim_win_get_cursor(0)[2]
        list.toggle_checkbox_insert()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local final_col = vim.api.nvim_win_get_cursor(0)[2]
        assert.are.equal("- [x] Todo item", lines[1])
        assert.are.equal(initial_col, final_col)
      end)
    end)
  end)
end)
