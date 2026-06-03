---Test suite for markdown-plus.nvim list type toggling
---@diagnostic disable: undefined-field
local toggle = require("markdown-plus.list.toggle")

describe("markdown-plus list toggle", function()
  local buf

  ---Replace the buffer contents with the given lines.
  ---@param lines string[]
  local function set_lines(lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  ---Get all buffer lines.
  ---@return string[]
  local function get_lines()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

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

  describe("single line conversion", function()
    it("adds an unordered marker to plain text", function()
      set_lines({ "hello world" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "- hello world" }, get_lines())
    end)

    it("adds a task marker to plain text", function()
      set_lines({ "buy milk" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("task")
      assert.are.same({ "- [ ] buy milk" }, get_lines())
    end)

    it("adds an ordered marker to plain text", function()
      set_lines({ "first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("ordered")
      assert.are.same({ "1. first" }, get_lines())
    end)

    it("preserves indentation", function()
      set_lines({ "    nested" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "    - nested" }, get_lines())
    end)
  end)

  describe("toggle off (same type)", function()
    it("removes an unordered marker", function()
      set_lines({ "- hello" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "hello" }, get_lines())
    end)

    it("toggles off a star bullet with the unordered target", function()
      set_lines({ "* hello" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "hello" }, get_lines())
    end)

    it("toggles off a plus bullet with the unordered target", function()
      set_lines({ "+ hello" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "hello" }, get_lines())
    end)

    it("removes a task marker including checkbox", function()
      set_lines({ "- [x] done" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("task")
      assert.are.same({ "done" }, get_lines())
    end)

    it("removes an ordered marker", function()
      set_lines({ "1. first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("ordered")
      assert.are.same({ "first" }, get_lines())
    end)
  end)

  describe("conversion between types", function()
    it("converts unordered to ordered", function()
      set_lines({ "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("ordered")
      assert.are.same({ "1. item" }, get_lines())
    end)

    it("converts ordered to unordered", function()
      set_lines({ "1. item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "- item" }, get_lines())
    end)

    it("converts unordered to task", function()
      set_lines({ "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("task")
      assert.are.same({ "- [ ] item" }, get_lines())
    end)

    it("drops the checkbox when converting task to unordered", function()
      set_lines({ "- [x] item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("unordered")
      assert.are.same({ "- item" }, get_lines())
    end)

    it("preserves the checkbox when converting task to ordered", function()
      set_lines({ "- [x] item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("ordered")
      assert.are.same({ "1. [x] item" }, get_lines())
    end)

    it("normalizes a star bullet task to a dash task", function()
      set_lines({ "* [ ] item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("task")
      assert.are.same({ "- [ ] item" }, get_lines())
    end)
  end)

  describe("alpha and paren ordered types", function()
    it("converts plain text to lowercase letter list", function()
      set_lines({ "item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("letter_lower")
      assert.are.same({ "a. item" }, get_lines())
    end)

    it("converts plain text to parenthesized ordered list", function()
      set_lines({ "item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.toggle_list_line("ordered_paren")
      assert.are.same({ "1) item" }, get_lines())
    end)
  end)

  describe("visual range", function()
    it("converts a block of plain text to a numbered list", function()
      set_lines({ "one", "two", "three" })
      toggle.toggle_list_in_range(1, 3, "ordered")
      assert.are.same({ "1. one", "2. two", "3. three" }, get_lines())
    end)

    it("converts a block to a lowercase letter list with correct sequence", function()
      set_lines({ "one", "two", "three" })
      toggle.toggle_list_in_range(1, 3, "letter_lower")
      assert.are.same({ "a. one", "b. two", "c. three" }, get_lines())
    end)

    it("converts a block to an unordered list", function()
      set_lines({ "one", "two" })
      toggle.toggle_list_in_range(1, 2, "unordered")
      assert.are.same({ "- one", "- two" }, get_lines())
    end)

    it("clears a numbered list when all lines already match", function()
      set_lines({ "1. one", "2. two", "3. three" })
      toggle.toggle_list_in_range(1, 3, "ordered")
      assert.are.same({ "one", "two", "three" }, get_lines())
    end)

    it("converts (not clears) a mixed selection", function()
      set_lines({ "1. one", "plain", "3. three" })
      toggle.toggle_list_in_range(1, 3, "ordered")
      assert.are.same({ "1. one", "2. plain", "3. three" }, get_lines())
    end)

    it("skips blank lines and restarts numbering across a list break", function()
      set_lines({ "one", "", "two" })
      toggle.toggle_list_in_range(1, 3, "ordered")
      -- A non-continuation blank line breaks list groups, so each side
      -- forms its own list and restarts numbering (established renumber behavior).
      assert.are.same({ "1. one", "", "1. two" }, get_lines())
    end)

    it("clears a mixed-bullet selection with the unordered target", function()
      set_lines({ "- one", "* two", "+ three" })
      toggle.toggle_list_in_range(1, 3, "unordered")
      assert.are.same({ "one", "two", "three" }, get_lines())
    end)

    it("handles a reversed range", function()
      set_lines({ "one", "two" })
      toggle.toggle_list_in_range(2, 1, "unordered")
      assert.are.same({ "- one", "- two" }, get_lines())
    end)
  end)

  describe("surrounding context numbering", function()
    it("continues an existing ordered list when converting prose in the middle", function()
      set_lines({ "1. before", "middle", "after", "4. last" })
      toggle.toggle_list_in_range(2, 3, "ordered")
      assert.are.same({ "1. before", "2. middle", "3. after", "4. last" }, get_lines())
    end)
  end)

  describe("edge cases", function()
    it("does nothing for an all-blank selection", function()
      set_lines({ "", "" })
      toggle.toggle_list_in_range(1, 2, "ordered")
      assert.are.same({ "", "" }, get_lines())
    end)

    it("ignores unknown target types", function()
      set_lines({ "item" })
      toggle.toggle_list_in_range(1, 1, "bogus")
      assert.are.same({ "item" }, get_lines())
    end)
  end)

  describe("clear_list_in_range", function()
    it("strips markers from a mixed-type selection", function()
      set_lines({ "- one", "1. two", "a) three" })
      toggle.clear_list_in_range(1, 3)
      assert.are.same({ "one", "two", "three" }, get_lines())
    end)

    it("strips checkboxes too", function()
      set_lines({ "- [x] done", "1. [ ] todo" })
      toggle.clear_list_in_range(1, 2)
      assert.are.same({ "done", "todo" }, get_lines())
    end)

    it("leaves plain and blank lines untouched", function()
      set_lines({ "- one", "", "plain" })
      toggle.clear_list_in_range(1, 3)
      assert.are.same({ "one", "", "plain" }, get_lines())
    end)
  end)

  describe("clear_list_line", function()
    it("clears the current line", function()
      set_lines({ "1. [x] item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.clear_list_line()
      assert.are.same({ "item" }, get_lines())
    end)

    it("leaves a plain line untouched", function()
      set_lines({ "plain" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle.clear_list_line()
      assert.are.same({ "plain" }, get_lines())
    end)
  end)

  describe("clear_list_range", function()
    it("clears the current visual selection", function()
      set_lines({ "- one", "1. two", "a) three" })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("ggVG", true, false, true), "x", false)
      toggle.clear_list_range()
      assert.are.same({ "one", "two", "three" }, get_lines())
    end)
  end)

  describe("picker dispatcher", function()
    local orig_read_key

    before_each(function()
      orig_read_key = toggle.read_key
    end)

    after_each(function()
      toggle.read_key = orig_read_key
    end)

    ---Stub the next picker keypress.
    ---@param key string|nil
    local function stub_key(key)
      toggle.read_key = function()
        return key
      end
    end

    it("maps each key to the matching list type on the current line", function()
      local cases = {
        u = "- item",
        t = "- [ ] item",
        n = "1. item",
        N = "1) item",
        l = "a. item",
        L = "A. item",
        p = "a) item",
        P = "A) item",
      }
      for key, expected in pairs(cases) do
        set_lines({ "item" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        stub_key(key)
        toggle.toggle_list_pick_line()
        assert.are.same({ expected }, get_lines(), "key " .. key)
      end
    end)

    it("clears the line on key 'c'", function()
      set_lines({ "1. item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      stub_key("c")
      toggle.toggle_list_pick_line()
      assert.are.same({ "item" }, get_lines())
    end)

    it("does nothing on an unmapped key", function()
      set_lines({ "item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      stub_key("z")
      toggle.toggle_list_pick_line()
      assert.are.same({ "item" }, get_lines())
    end)

    it("does nothing when the picker is cancelled (nil key)", function()
      set_lines({ "item" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      stub_key(nil)
      toggle.toggle_list_pick_line()
      assert.are.same({ "item" }, get_lines())
    end)
  end)
end)
