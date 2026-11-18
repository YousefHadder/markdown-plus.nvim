---Test suite for checkbox sync after edits (`list.checkbox_sync` with indent, delete, paste, ...)
---@diagnostic disable: undefined-field
local list = require("markdown-plus.list")
local checkbox_sync = require("markdown-plus.list.checkbox_sync")
local checkbox_autocmds = require("markdown-plus.list.checkbox_autocmds")

local AUGROUP_PREFIX = "MarkdownPlusCheckboxSync_"

describe("markdown-plus checkbox sync after edits", function()
  local buf
  local markdown_plus
  local original_list_config
  local timers, timer_start, timer_stop

  ---Close the current undo block, as returning to the user does
  ---@return nil
  local function close_undo_block()
    vim.bo.undolevels = vim.bo.undolevels
  end

  ---@param lines string[]
  ---@return nil
  local function set_lines(lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    close_undo_block()
    checkbox_autocmds.refresh(buf)
  end

  ---@return string[]
  local function get_lines()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  ---@param event string
  ---@return nil
  local function emit(event)
    vim.api.nvim_exec_autocmds(event, { buffer = buf })
  end

  ---Run a normal mode command as a user edit and deliver its TextChanged
  ---@param keys string
  ---@return nil
  local function normal(keys)
    vim.cmd("normal! " .. vim.keycode(keys))
    close_undo_block()
    emit("TextChanged")
  end

  ---@param row number
  ---@param keys string
  ---@return nil
  local function normal_at(row, keys)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    normal(keys)
  end

  ---@return nil
  local function drain()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do
      callback()
    end
  end

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].shiftwidth = 2
    vim.bo[buf].expandtab = true
    markdown_plus = require("markdown-plus")
    original_list_config = markdown_plus.config.list
    markdown_plus.config.list = vim.tbl_deep_extend("force", vim.deepcopy(original_list_config or {}), {
      checkbox_sync = true,
      checkbox_completion = { enabled = false },
    })
    timers = {}
    timer_start, timer_stop = vim.fn.timer_start, vim.fn.timer_stop
    vim.fn.timer_start = function(_, callback)
      timers[#timers + 1] = callback
      return #timers
    end
    vim.fn.timer_stop = function() end
    checkbox_autocmds.setup()
  end)

  after_each(function()
    checkbox_autocmds.teardown()
    vim.fn.timer_start, vim.fn.timer_stop = timer_start, timer_stop
    markdown_plus.config.list = original_list_config
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("indenting and outdenting", function()
    it("recomputes the new parent and its ancestors when an item is indented", function()
      set_lines({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" })
      normal_at(3, ">>")
      assert.are.same({ "- [x] parent", "  - [x] child1", "    - [x] child2" }, get_lines())
    end)

    it("reopens the new parent when an open item is indented under it", function()
      set_lines({ "- [x] done", "- [ ] open" })
      normal_at(2, ">>")
      assert.are.same({ "- [ ] done", "  - [ ] open" }, get_lines())
    end)

    it("recomputes the old parent when an item is outdented out of it", function()
      set_lines({ "- [ ] parent", "  - [x] done", "  - [ ] open" })
      normal_at(3, "<<")
      assert.are.same({ "- [x] parent", "  - [x] done", "- [ ] open" }, get_lines())
    end)

    it("recomputes an outdented item that takes over the following items", function()
      set_lines({ "- [ ] parent", "  - [x] done", "    - [ ] open" })
      normal_at(2, "<<")
      -- `open` is now the only child of `done`
      assert.are.same({ "- [ ] parent", "- [ ] done", "    - [ ] open" }, get_lines())
    end)

    it("handles a visual indent of a whole subtree", function()
      set_lines({ "- [ ] first", "- [x] second", "  - [x] nested" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      normal("Vj>")
      assert.are.same({ "- [x] first", "  - [x] second", "    - [x] nested" }, get_lines())
    end)

    it("syncs the insert mode Tab once typing pauses", function()
      set_lines({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" })
      vim.api.nvim_win_set_cursor(0, { 3, 4 })
      list.handle_tab()
      emit("TextChangedI")
      assert.are.same({ "- [ ] parent", "  - [ ] child1", "    - [x] child2" }, get_lines())
      drain()
      assert.are.same({ "- [x] parent", "  - [x] child1", "    - [x] child2" }, get_lines())
    end)

    it("drops a pending insert mode sync when the buffer changed again", function()
      set_lines({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" })
      vim.api.nvim_win_set_cursor(0, { 3, 4 })
      list.handle_tab()
      emit("TextChangedI")
      vim.api.nvim_buf_set_lines(buf, 3, 3, false, { "" })
      drain()
      assert.are.same({ "- [ ] parent", "  - [ ] child1", "    - [x] child2", "" }, get_lines())
    end)
  end)

  describe("adding and removing items", function()
    it("reopens a checked parent when an open item is added under it", function()
      set_lines({ "- [x] parent", "  - [x] done" })
      normal_at(2, "o- [ ] new")
      assert.are.same({ "- [ ] parent", "  - [x] done", "  - [ ] new" }, get_lines())
    end)

    it("checks the parent when its last open child is deleted", function()
      set_lines({ "- [ ] parent", "  - [x] done", "  - [ ] open" })
      normal_at(3, "dd")
      assert.are.same({ "- [x] parent", "  - [x] done" }, get_lines())
    end)

    it("leaves a parent alone when its last child is deleted", function()
      set_lines({ "- [x] parent", "  - [x] only" })
      normal_at(2, "dd")
      assert.are.same({ "- [x] parent" }, get_lines())
    end)

    it("recomputes both parents when an item is moved between them", function()
      set_lines({ "- [ ] a", "  - [x] a1", "  - [ ] a2", "- [x] b", "  - [x] b1" })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.cmd("move 5")
      close_undo_block()
      emit("TextChanged")
      assert.are.same({ "- [x] a", "  - [x] a1", "- [ ] b", "  - [x] b1", "  - [ ] a2" }, get_lines())
    end)

    it("recomputes the parent of a pasted subtree", function()
      set_lines({ "- [ ] source", "  - [ ] open", "- [x] target", "  - [x] done" })
      normal_at(2, "yy")
      normal_at(4, "p")
      assert.are.same({ "- [ ] source", "  - [ ] open", "- [ ] target", "  - [x] done", "  - [ ] open" }, get_lines())
    end)

    it("recomputes the parent when a child's checkbox is removed", function()
      set_lines({ "- [ ] parent", "  - [x] done", "  - [ ] open" })
      vim.api.nvim_win_set_cursor(0, { 3, 4 })
      normal("4x")
      assert.are.same({ "- [x] parent", "  - [x] done", "  - open" }, get_lines())
    end)
  end)

  describe("editing a checkbox by hand", function()
    it("pushes a hand-written state down like a toggle", function()
      set_lines({ "- [ ] parent", "  - [ ] child", "    - [ ] grandchild" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      normal("rx")
      assert.are.same({ "- [x] parent", "  - [x] child", "    - [x] grandchild" }, get_lines())
    end)

    it("updates the parents of a hand-written state", function()
      set_lines({ "- [ ] parent", "  - [x] done", "  - [ ] open" })
      vim.api.nvim_win_set_cursor(0, { 3, 5 })
      normal("rx")
      assert.are.same({ "- [x] parent", "  - [x] done", "  - [x] open" }, get_lines())
    end)

    it("does not push a hand-written checkbox down", function()
      set_lines({ "- parent", "  - [x] done" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal("a [ ]")
      assert.are.same({ "- [ ] parent", "  - [x] done" }, get_lines())
    end)
  end)

  describe("leaves the buffer alone", function()
    it("for edits that keep the list structure", function()
      set_lines({ "- [x] inconsistent parent", "  - [ ] child" })
      normal_at(2, "Aa")
      assert.are.same({ "- [x] inconsistent parent", "  - [ ] childa" }, get_lines())
    end)

    it("when checkbox sync is disabled at runtime", function()
      markdown_plus.config.list.checkbox_sync = false
      set_lines({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" })
      normal_at(3, ">>")
      emit("TextChangedI")
      drain()
      assert.are.same({ "- [ ] parent", "  - [ ] child1", "    - [x] child2" }, get_lines())
    end)

    it("after a toggle, whose sync already ran", function()
      set_lines({ "- [ ] parent", "  - [x] selected", "  - [ ] other" })
      vim.cmd("normal! ggVj")
      list.toggle_checkbox_range()
      vim.cmd("normal! \27")
      close_undo_block()
      local after_toggle = get_lines()
      emit("TextChanged")
      assert.are.same(after_toggle, get_lines())
    end)
  end)

  describe("undo", function()
    it("reverts an edit and its sync in one step without syncing again", function()
      set_lines({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" })
      normal_at(3, ">>")
      vim.cmd("silent undo")
      emit("TextChanged")
      assert.are.same({ "- [ ] parent", "  - [ ] child1", "  - [x] child2" }, get_lines())
      vim.cmd("silent redo")
      emit("TextChanged")
      assert.are.same({ "- [x] parent", "  - [x] child1", "    - [x] child2" }, get_lines())
    end)

    it("does not resync text restored by undo", function()
      set_lines({ "- [x] inconsistent parent", "  - [ ] one", "  - [ ] two" })
      vim.api.nvim_win_set_cursor(0, { 2, 5 })
      normal("rx")
      assert.are.same({ "- [ ] inconsistent parent", "  - [x] one", "  - [ ] two" }, get_lines())
      vim.cmd("silent undo")
      emit("TextChanged")
      assert.are.same({ "- [x] inconsistent parent", "  - [ ] one", "  - [ ] two" }, get_lines())
    end)
  end)

  describe("lifecycle", function()
    it("is not set up while checkbox sync is disabled", function()
      checkbox_autocmds.teardown()
      markdown_plus.config.list.checkbox_sync = false
      checkbox_autocmds.setup()
      assert.has_error(function()
        vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf })
      end)
    end)

    it("removes the buffer's autocommands on disable", function()
      checkbox_autocmds.disable(buf)
      assert.has_error(function()
        vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf })
      end)
    end)

    it("is set up and torn down with the list module", function()
      checkbox_autocmds.teardown()
      list.setup_keymaps()
      assert.is_true(#vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf }) > 0)
      list.disable(buf)
      assert.has_error(function()
        vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf })
      end)
      list.setup_keymaps()
      list.teardown()
      assert.has_error(function()
        vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf })
      end)
    end)

    it("takes a reloaded file as the new baseline", function()
      local path = vim.fn.tempname() .. ".md"
      vim.fn.writefile({ "- [ ] parent", "  - [x] child" }, path)
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      local file_buf = vim.api.nvim_get_current_buf()
      vim.bo.filetype = "markdown"
      checkbox_autocmds.setup()
      vim.fn.writefile({ "- [ ] parent", "  - [x] child", "  - [x] other" }, path)
      vim.cmd("silent edit!")
      vim.api.nvim_exec_autocmds("TextChanged", { buffer = file_buf })
      assert.are.same(
        { "- [ ] parent", "  - [x] child", "  - [x] other" },
        vim.api.nvim_buf_get_lines(file_buf, 0, -1, false)
      )
      vim.api.nvim_buf_delete(file_buf, { force = true })
      vim.fn.delete(path)
    end)
  end)

  describe("classify_edit", function()
    local key = checkbox_sync.line_key

    it("reports checkbox-only changes like toggles", function()
      assert.are.same({ added = false }, checkbox_sync.classify_edit(key("  - [ ] b"), key("  - [x] b")))
      assert.are.same({ added = true }, checkbox_sync.classify_edit(key("  - c"), key("  - [ ] c")))
      assert.are.same({ added = false }, checkbox_sync.classify_edit(key("  - [ ] c"), key("  - c")))
    end)

    it("reports indentation and list changes as structural", function()
      assert.are.same({ structural = true }, checkbox_sync.classify_edit(key("- [ ] b"), key("  - [ ] b")))
      assert.are.same({ structural = true }, checkbox_sync.classify_edit(key("- [ ] b"), key("[ ] b")))
      assert.are.same({ structural = true }, checkbox_sync.classify_edit(key("text"), key("")))
    end)

    it("ignores text edits", function()
      assert.is_nil(checkbox_sync.classify_edit(key("- [ ] a"), key("- [ ] abc")))
      assert.is_nil(checkbox_sync.classify_edit(key("text"), key("more text")))
    end)
  end)
end)
