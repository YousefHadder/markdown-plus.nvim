---Test suite for checkbox state cycling (`list.checkbox_states`, `<Plug>(MarkdownPlusCycleCheckbox)`)
---@diagnostic disable: undefined-field
local list = require("markdown-plus.list")
local checkbox_sync = require("markdown-plus.list.checkbox_sync")

describe("markdown-plus checkbox cycle", function()
  local buf
  local markdown_plus
  local original_list_config

  ---@param lines string[]
  local function set_lines(lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  ---@return string[]
  local function get_lines()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  ---Cycle line 1 of a single-line buffer and return the resulting line
  ---@param line string
  ---@return string
  local function cycle(line)
    set_lines({ line })
    list.cycle_checkbox_on_line(1)
    return get_lines()[1]
  end

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
    markdown_plus = require("markdown-plus")
    original_list_config = markdown_plus.config.list
    markdown_plus.config.list = vim.tbl_deep_extend("force", vim.deepcopy(original_list_config or {}), {
      checkbox_sync = false,
      checkbox_completion = { enabled = false },
    })
    markdown_plus.config.list.checkbox_states = { " ", "/", "x" }
  end)

  after_each(function()
    markdown_plus.config.list = original_list_config
    vim.cmd("stopinsert")
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("next_state", function()
    it("steps through the states and wraps around", function()
      local states = { " ", "/", "x" }
      assert.are.equal("/", checkbox_sync.next_state(" ", states))
      assert.are.equal("x", checkbox_sync.next_state("/", states))
      assert.are.equal(" ", checkbox_sync.next_state("x", states))
    end)

    it("treats X as x", function()
      assert.are.equal(" ", checkbox_sync.next_state("X", { " ", "/", "x" }))
    end)

    it("starts unknown states over at the first state", function()
      assert.are.equal(" ", checkbox_sync.next_state("-", { " ", "/", "x" }))
    end)

    it("defaults to unchecked and checked", function()
      assert.are.equal("x", checkbox_sync.next_state(" "))
      assert.are.equal(" ", checkbox_sync.next_state("x"))
    end)
  end)

  describe("cycle_checkbox_on_line", function()
    it("cycles through every configured state", function()
      set_lines({ "- [ ] task" })
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [/] task" }, get_lines())
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [x] task" }, get_lines())
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [ ] task" }, get_lines())
    end)

    it("adds a checkbox to a plain list item", function()
      assert.are.equal("- [ ] plain", cycle("- plain"))
    end)

    it("resets a custom state to the first state", function()
      assert.are.equal("- [ ] cancelled", cycle("- [-] cancelled"))
    end)

    it("behaves like toggle with the default states", function()
      markdown_plus.config.list.checkbox_states = nil
      assert.are.equal("- [x] task", cycle("- [ ] task"))
      assert.are.equal("1. [ ] task", cycle("1. [X] task"))
    end)

    it("works with ordered and letter lists", function()
      assert.are.equal("1. [/] task", cycle("1. [ ] task"))
      assert.are.equal("  a) [x] task", cycle("  a) [/] task"))
    end)

    it("handles an empty checkbox at the end of the line", function()
      assert.are.equal("- [/] ", cycle("- [ ]"))
    end)

    it("does nothing on non-list lines", function()
      assert.are.equal("plain text", cycle("plain text"))
    end)

    it("adds a completion timestamp when reaching x and removes it when leaving", function()
      markdown_plus.config.list.checkbox_completion = {
        enabled = true,
        format = "emoji",
        date_format = "%Y-%m-%d",
        remove_on_uncheck = true,
        update_existing = true,
      }
      local checked = cycle("- [/] task")
      assert.is_not_nil(checked:match("^%- %[x%] task ✅ %d%d%d%d%-%d%d%-%d%d$"))
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [ ] task" }, get_lines())
    end)
  end)

  describe("entry points", function()
    it("cycles the current line", function()
      set_lines({ "- [ ] one", "- [ ] two" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      list.cycle_checkbox_line()
      assert.are.same({ "- [ ] one", "- [/] two" }, get_lines())
    end)

    it("cycles every line of a visual range", function()
      set_lines({ "- [ ] one", "- [/] two", "- three", "text" })
      vim.cmd("normal! ggVG")
      list.cycle_checkbox_range()
      assert.are.same({ "- [/] one", "- [x] two", "- [ ] three", "text" }, get_lines())
    end)

    it("keeps the cursor in place in insert mode", function()
      set_lines({ "- task" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })
      list.cycle_checkbox_insert()
      assert.are.same({ "- [ ] task" }, get_lines())
      assert.are.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
    end)
  end)

  describe("with checkbox_sync", function()
    before_each(function()
      markdown_plus.config.list.checkbox_sync = true
    end)

    it("marks the parent in progress when a child starts", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [ ] two" })
      list.cycle_checkbox_on_line(2)
      assert.are.same({ "- [/] parent", "  - [/] one", "  - [ ] two" }, get_lines())
    end)

    it("marks the parent in progress when only some children are done", function()
      set_lines({ "- [ ] parent", "  - [/] one", "  - [ ] two" })
      list.cycle_checkbox_on_line(2)
      assert.are.same({ "- [/] parent", "  - [x] one", "  - [ ] two" }, get_lines())
    end)

    it("checks the parent when the last child is done", function()
      set_lines({ "- [/] parent", "  - [x] one", "  - [/] two" })
      list.cycle_checkbox_on_line(3)
      assert.are.same({ "- [x] parent", "  - [x] one", "  - [x] two" }, get_lines())
    end)

    it("reopens the parent when every child is open again", function()
      set_lines({ "- [/] parent", "  - [x] one", "  - [ ] two" })
      list.cycle_checkbox_on_line(2)
      assert.are.same({ "- [ ] parent", "  - [ ] one", "  - [ ] two" }, get_lines())
    end)

    it("does not push an in-between state down to children", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [ ] two" })
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [/] parent", "  - [ ] one", "  - [ ] two" }, get_lines())
    end)

    it("pushes the last state down over in-between children", function()
      set_lines({ "- [/] parent", "  - [/] one", "  - [ ] two" })
      list.cycle_checkbox_on_line(1)
      assert.are.same({ "- [x] parent", "  - [x] one", "  - [x] two" }, get_lines())
    end)

    it("uses the in-between state when toggling too", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [ ] two" })
      list.toggle_checkbox_on_line(2)
      assert.are.same({ "- [/] parent", "  - [x] one", "  - [ ] two" }, get_lines())
    end)

    it("still ignores states that are not configured", function()
      set_lines({ "- [ ] parent", "  - [-] cancelled", "  - [/] two" })
      list.cycle_checkbox_on_line(3)
      assert.are.same({ "- [x] parent", "  - [-] cancelled", "  - [x] two" }, get_lines())
    end)
  end)

  describe("with checkbox_sync after edits", function()
    local checkbox_autocmds = require("markdown-plus.list.checkbox_autocmds")

    before_each(function()
      markdown_plus.config.list.checkbox_sync = true
      vim.bo[buf].shiftwidth = 2
      vim.bo[buf].expandtab = true
      checkbox_autocmds.setup()
    end)

    after_each(function()
      checkbox_autocmds.teardown()
    end)

    ---@param row number
    ---@param col number
    ---@param keys string
    local function normal_at(row, col, keys)
      vim.bo[buf].undolevels = vim.bo[buf].undolevels
      checkbox_autocmds.refresh(buf)
      vim.api.nvim_win_set_cursor(0, { row, col })
      vim.cmd("normal! " .. keys)
      vim.bo[buf].undolevels = vim.bo[buf].undolevels
      vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    end

    it("marks the new parent in progress when a done item is indented under an open one", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [x] two", "  - [ ] three" })
      normal_at(3, 0, ">>")
      assert.are.same({ "- [/] parent", "  - [x] one", "    - [x] two", "  - [ ] three" }, get_lines())
    end)

    it("marks the parent in progress when an in-between state is typed by hand", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [ ] two" })
      normal_at(2, 5, "r/")
      assert.are.same({ "- [/] parent", "  - [/] one", "  - [ ] two" }, get_lines())
    end)
  end)

  describe("keymaps", function()
    it("registers <Plug>(MarkdownPlusCycleCheckbox) with <localleader>mX in normal and visual mode", function()
      markdown_plus.setup({})
      for _, mode in ipairs({ "n", "x", "i" }) do
        assert.are_not.equal("", vim.fn.maparg("<Plug>(MarkdownPlusCycleCheckbox)", mode))
      end
      for _, mode in ipairs({ "n", "x" }) do
        local map = vim.fn.maparg("<localleader>mX", mode, false, true)
        assert.are.equal("<Plug>(MarkdownPlusCycleCheckbox)", map.rhs)
        assert.are.equal(1, map.buffer)
      end
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "i")) do
        assert.are_not.equal("<Plug>(MarkdownPlusCycleCheckbox)", map.rhs)
      end
    end)
  end)
end)
