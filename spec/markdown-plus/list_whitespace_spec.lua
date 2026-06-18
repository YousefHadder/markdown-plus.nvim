---Test suite for configurable list marker-to-content whitespace (issue #365)
---Covers the shared.spaces_after_marker helper, get_content_start_col, and the
---generation sites (renumber + build_list_prefix) under "single" and "shiftwidth"
---modes. "single" mode must stay byte-identical to the historical behavior.
---@diagnostic disable: undefined-field
local shared = require("markdown-plus.list.shared")
local handler_utils = require("markdown-plus.list.handler_utils")
local list = require("markdown-plus.list")

describe("markdown-plus list whitespace", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
  end)

  after_each(function()
    -- Reset to the default so other describe blocks / files are never affected.
    shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("spaces_after_marker", function()
    it("always returns a single space in single mode", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      assert.are.equal(" ", shared.spaces_after_marker("1."))
      assert.are.equal(" ", shared.spaces_after_marker("100."))
      assert.are.equal(" ", shared.spaces_after_marker("-"))
      assert.are.equal(" ", shared.spaces_after_marker("1. [x]"))
    end)

    it("defaults to single mode when no list config is given", function()
      shared.set_whitespace_config(nil)
      assert.are.equal(" ", shared.spaces_after_marker("1."))
    end)

    it("pads ordered markers to the width-4 block in shiftwidth mode", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      assert.are.equal("  ", shared.spaces_after_marker("1.")) -- len 2 -> content col 4
      assert.are.equal(" ", shared.spaces_after_marker("10.")) -- len 3 -> content col 4
      assert.are.equal("    ", shared.spaces_after_marker("100.")) -- len 4 -> content col 8
    end)

    it("pads unordered markers to three spaces at width 4 (reporter's case)", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      assert.are.equal("   ", shared.spaces_after_marker("-")) -- len 1 -> content col 4
    end)

    it("treats the checkbox bracket as part of the marker", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      assert.are.equal("  ", shared.spaces_after_marker("1. [x]")) -- len 6 -> content col 8
    end)

    it("honors a custom whitespace_width", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 2 })
      assert.are.equal(" ", shared.spaces_after_marker("-")) -- len 1 -> col 2
      assert.are.equal("  ", shared.spaces_after_marker("1.")) -- len 2 -> col 4
    end)

    it("never returns fewer than one space", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      for _, marker in ipairs({ "1.", "10.", "100.", "-", "+", "a)", "1. [ ]" }) do
        assert.is_true(#shared.spaces_after_marker(marker) >= 1)
      end
    end)
  end)

  describe("get_content_start_col", function()
    it("matches the single-space layout in single mode", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      assert.are.equal(3, shared.get_content_start_col({ indent = "", full_marker = "1." }))
    end)

    it("reflects the padded content column in shiftwidth mode", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      -- Continuation lines align here, fixing the reporter's misalignment.
      assert.are.equal(4, shared.get_content_start_col({ indent = "", full_marker = "1." }))
      assert.are.equal(4, shared.get_content_start_col({ indent = "", full_marker = "10." }))
      assert.are.equal(8, shared.get_content_start_col({ indent = "", full_marker = "100." }))
    end)
  end)

  describe("build_list_prefix", function()
    it("produces the historical layout in single mode", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      assert.are.equal("1. ", handler_utils.build_list_prefix("", "1.", nil))
      assert.are.equal("- ", handler_utils.build_list_prefix("", "-", nil))
      assert.are.equal("1. [ ] ", handler_utils.build_list_prefix("", "1.", " "))
    end)

    it("pads to the alignment block in shiftwidth mode", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      assert.are.equal("1.  ", handler_utils.build_list_prefix("", "1.", nil))
      assert.are.equal("-   ", handler_utils.build_list_prefix("", "-", nil))
      -- Checkbox is part of the marker: "1. [ ]" (len 6) -> 2 pad spaces.
      assert.are.equal("1. [ ]  ", handler_utils.build_list_prefix("", "1.", " "))
    end)
  end)

  describe("renumber_ordered_lists", function()
    it("keeps a single space after the marker in single mode", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Alpha", "2. Beta" })
      list.renumber_ordered_lists()
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1. Alpha", result[1])
      assert.are.equal("2. Beta", result[2])
    end)

    it("aligns content to the width block in shiftwidth mode", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Alpha", "2. Beta" })
      list.renumber_ordered_lists()
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1.  Alpha", result[1])
      assert.are.equal("2.  Beta", result[2])
    end)

    it("does not collapse the user's aligned spacing on edit (issue #365)", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      -- User typed content already aligned to a 4-space block.
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1.  Item 1", "2.  Item 2" })
      list.renumber_ordered_lists()
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1.  Item 1", result[1])
      assert.are.equal("2.  Item 2", result[2])
    end)

    it("collapses extra spacing back to single space in single mode", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1.  Item 1", "2.  Item 2" })
      list.renumber_ordered_lists()
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal("1. Item 1", result[1])
      assert.are.equal("2. Item 2", result[2])
    end)
  end)

  -- Regression: renumber rewrites the cursor's line via nvim_buf_set_lines, which
  -- keeps the cursor's absolute column. When the marker→content prefix grows or
  -- shrinks, the cursor must follow its content character instead of drifting.
  describe("cursor preservation on renumber", function()
    it("keeps the cursor on the same content char when padding grows (shiftwidth)", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      -- "1. Alpha" typed with one space; cursor on the final 'a' (col 7, 0-based).
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Alpha" })
      vim.api.nvim_win_set_cursor(0, { 1, 7 })

      list.renumber_ordered_lists()

      assert.are.equal("1.  Alpha", vim.api.nvim_get_current_line())
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(8, cursor[2]) -- shifted right by the +1 pad
      local line = vim.api.nvim_get_current_line()
      assert.are.equal("a", line:sub(cursor[2] + 1, cursor[2] + 1))
    end)

    it("keeps the cursor on the same content char when spacing collapses (single)", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      -- "1.  First" typed with two spaces; cursor on 'F' (col 4, 0-based).
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1.  First" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      list.renumber_ordered_lists()

      assert.are.equal("1. First", vim.api.nvim_get_current_line())
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(3, cursor[2]) -- shifted left by the -1 collapse
      local line = vim.api.nvim_get_current_line()
      assert.are.equal("F", line:sub(cursor[2] + 1, cursor[2] + 1))
    end)

    it("does not move the cursor when its line is unchanged", function()
      shared.set_whitespace_config({ whitespace = "single", whitespace_width = 4 })
      -- Line 1 is already correct; only line 2 needs renumbering.
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Alpha", "5. Beta" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- on line 1 (unchanged)

      list.renumber_ordered_lists()

      assert.are.equal("2. Beta", vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1])
      assert.are.same({ 1, 6 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("leaves the cursor in the prefix region without pushing it into content", function()
      shared.set_whitespace_config({ whitespace = "shiftwidth", whitespace_width = 4 })
      -- Cursor on the marker digit (col 0); padding grows after the marker.
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Alpha" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      list.renumber_ordered_lists()

      assert.are.equal("1.  Alpha", vim.api.nvim_get_current_line())
      assert.are.equal(0, vim.api.nvim_win_get_cursor(0)[2]) -- stays on the marker
    end)
  end)

  describe("checkbox spacing honors whitespace mode", function()
    local function parse(line)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
      return list.parse_list_line(line, 1)
    end

    it("single mode: adding a checkbox keeps one space (unchanged)", function()
      require("markdown-plus").setup({ list = { whitespace = "single" } })
      assert.are.equal("- [ ] thing", list.add_checkbox_to_line("- thing", parse("- thing")))
    end)

    it("single mode: toggling checkbox state keeps one space (unchanged)", function()
      require("markdown-plus").setup({ list = { whitespace = "single" } })
      assert.are.equal("- [x] Hello", list.replace_checkbox_state("- [ ] Hello", parse("- [ ] Hello")))
    end)

    it("shiftwidth mode: adding a checkbox aligns content to the block", function()
      require("markdown-plus").setup({ list = { whitespace = "shiftwidth", whitespace_width = 4 } })
      -- Full marker "- [ ]" (5 chars) -> 3 pad spaces -> content column 8.
      assert.are.equal("- [ ]   thing", list.add_checkbox_to_line("- thing", parse("- thing")))
    end)

    it("shiftwidth mode: checking a box preserves block alignment", function()
      require("markdown-plus").setup({ list = { whitespace = "shiftwidth", whitespace_width = 4 } })
      assert.are.equal("- [x]   Hello", list.replace_checkbox_state("- [ ]   Hello", parse("- [ ]   Hello")))
    end)

    it("shiftwidth mode: unchecking a box preserves block alignment", function()
      require("markdown-plus").setup({ list = { whitespace = "shiftwidth", whitespace_width = 4 } })
      assert.are.equal("- [ ]   Hello", list.replace_checkbox_state("- [x]   Hello", parse("- [x]   Hello")))
    end)
  end)

  describe("setup propagation", function()
    it("wires whitespace config through the public setup() path", function()
      require("markdown-plus").setup({ list = { whitespace = "shiftwidth", whitespace_width = 4 } })
      assert.are.equal("  ", shared.spaces_after_marker("1."))
      -- Restore defaults via the same public path.
      require("markdown-plus").setup({})
      assert.are.equal(" ", shared.spaces_after_marker("1."))
    end)
  end)
end)
