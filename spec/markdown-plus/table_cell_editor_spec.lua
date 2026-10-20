---@diagnostic disable: undefined-field
local cell_editor = require("markdown-plus.table.cell_editor")
local parser = require("markdown-plus.table.parser")

describe("table.cell_editor", function()
  local markdown_plus = require("markdown-plus")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    markdown_plus.setup({})
  end)

  after_each(function()
    markdown_plus.teardown()
  end)

  local function reset_to(lines)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end

  local function place_cursor_at(line_number, cell_text)
    local line = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]
    local s = line:find(cell_text, 1, true)
    assert.is_not_nil(s, "expected cell text to be present: " .. cell_text)
    vim.fn.cursor(line_number, s)
  end

  describe("open", function()
    it("returns a session and populates scratch with segments split on <br>", function()
      reset_to({
        "| Title  | B |",
        "| ------ | - |",
        "| one<br>two<br>three | y |",
      })
      place_cursor_at(3, "one")

      local state = cell_editor.open()
      assert.is_not_nil(state)
      assert.is_true(vim.api.nvim_buf_is_valid(state.scratch_buf))
      assert.is_true(vim.api.nvim_win_is_valid(state.scratch_win))

      local segments = vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false)
      assert.are.same({ "one", "two", "three" }, segments)

      state.cancel()
    end)

    it("populates scratch with single line when cell has no <br>", function()
      reset_to({
        "| A    | B |",
        "| ---- | - |",
        "| word | y |",
      })
      place_cursor_at(3, "word")

      local state = cell_editor.open()
      local segments = vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false)
      assert.are.same({ "word" }, segments)
      state.cancel()
    end)

    it("returns nil and notifies when not in a table", function()
      reset_to({ "plain text" })
      vim.fn.cursor(1, 1)
      assert.is_nil(cell_editor.open())
    end)

    it("rejects the separator row", function()
      reset_to({
        "| H | B |",
        "| - | - |",
        "| a | b |",
      })
      vim.fn.cursor(2, 3)
      assert.is_nil(cell_editor.open())
    end)

    it("returns nil when cell_editor.enabled is false", function()
      markdown_plus.setup({ table = { cell_editor = { enabled = false } } })
      reset_to({
        "| H | B |",
        "| - | - |",
        "| a | b |",
      })
      vim.fn.cursor(3, 3)
      assert.is_nil(cell_editor.open())
    end)
  end)

  describe("save", function()
    it("joins lines with <br> and writes back to the source cell", function()
      reset_to({
        "| H    | B |",
        "| ---- | - |",
        "| word | y |",
      })
      place_cursor_at(3, "word")

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "line one", "line two", "line three" })

      assert.is_true(state.save())

      -- Parse the resulting table; cells[2][1] must now contain the joined content
      local table_info = parser.get_table_at_cursor()
      assert.is_not_nil(table_info)
      assert.equals("line one<br>line two<br>line three", table_info.cells[2][1])
    end)

    it("uses the configured wrap_break token when joining lines", function()
      markdown_plus.setup({ table = { wrap_break = "<br/>" } })
      reset_to({
        "| H    | B |",
        "| ---- | - |",
        "| word | y |",
      })
      place_cursor_at(3, "word")

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "first", "second" })
      assert.is_true(state.save())

      local table_info = parser.get_table_at_cursor()
      assert.equals("first<br/>second", table_info.cells[2][1])
    end)

    it("preserves literal pipes when saving an edited cell", function()
      reset_to({
        "| A | B |",
        "| --- | --- |",
        "| old | keep |",
      })
      place_cursor_at(3, "old")

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "new|value" })
      assert.is_true(state.save())

      assert.are.same({ { "A", "B" }, { "new|value", "keep" } }, parser.get_table_at_cursor().cells)
    end)

    it("preserves odd and even backslash runs before edited literal pipes", function()
      for count = 1, 2 do
        reset_to({
          "| A | B |",
          "| --- | --- |",
          "| old | keep |",
        })
        place_cursor_at(3, "old")

        local content = "new" .. string.rep("\\", count) .. "|value"
        local parsed_content = "new" .. string.rep("\\", count - count % 2) .. "|value"
        local state = cell_editor.open()
        vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { content })
        assert.is_true(state.save())

        assert.are.same({ { "A", "B" }, { parsed_content, "keep" } }, parser.get_table_at_cursor().cells)
        require("markdown-plus.table").format_table()
        assert.are.same({ { "A", "B" }, { parsed_content, "keep" } }, parser.get_table_at_cursor().cells)
      end
    end)

    it("collapses an empty scratch buffer to an empty cell", function()
      reset_to({
        "| H        | B |",
        "| -------- | - |",
        "| original | y |",
      })
      place_cursor_at(3, "original")

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, {})
      assert.is_true(state.save())

      local table_info = parser.get_table_at_cursor()
      assert.equals("", table_info.cells[2][1])
    end)

    it("closes the popup after saving", function()
      reset_to({
        "| H | B |",
        "| - | - |",
        "| a | b |",
      })
      place_cursor_at(3, "a")

      local state = cell_editor.open()
      local win = state.scratch_win
      state.save()
      assert.is_false(vim.api.nvim_win_is_valid(win))
    end)

    it("places the cursor back at the same logical cell even after widths change", function()
      reset_to({
        "| Short | B |",
        "| ----- | - |",
        "| a     | y |",
      })
      place_cursor_at(3, "a")

      local state = cell_editor.open()
      local edit_pos = state.pos
      -- Write content longer than the original so column 1 grows
      vim.api.nvim_buf_set_lines(
        state.scratch_buf,
        0,
        -1,
        false,
        { "this is a much longer cell content", "spanning two lines" }
      )
      assert.is_true(state.save())

      -- After save+reformat the cursor must be inside column 1 of the data row
      local updated = parser.get_table_at_cursor()
      assert.is_not_nil(updated)
      local pos_after = parser.get_cursor_position_in_table()
      assert.is_not_nil(pos_after)
      assert.equals(edit_pos.row, pos_after.row)
      assert.equals(edit_pos.col, pos_after.col)
    end)

    it("can be undone in a single u step", function()
      reset_to({
        "| H        | B |",
        "| -------- | - |",
        "| original | y |",
      })
      place_cursor_at(3, "original")

      local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "new content with multiple", "lines now" })
      assert.is_true(state.save())

      local after_save = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are_not.same(before, after_save)

      vim.cmd("undo")
      local after_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same(before, after_undo)
    end)
  end)

  describe("cancel", function()
    it("closes the popup without modifying the source buffer", function()
      reset_to({
        "| H        | B |",
        "| -------- | - |",
        "| original | y |",
      })
      place_cursor_at(3, "original")

      local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "discarded", "edits" })
      local win = state.scratch_win
      assert.is_true(state.cancel())

      assert.is_false(vim.api.nvim_win_is_valid(win))
      assert.are.same(before, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe("save guards against buffer drift", function()
    it("refuses to save when the original window has switched to a different buffer", function()
      reset_to({
        "| H        | B |",
        "| -------- | - |",
        "| original | y |",
      })
      place_cursor_at(3, "original")

      local orig_buf = vim.api.nvim_get_current_buf()
      local orig_lines = vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false)

      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "edits", "from", "popup" })

      -- Simulate the user (or another autocmd) swapping the original window's buffer.
      local other_buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(other_buf, 0, -1, false, { "unrelated content" })
      vim.api.nvim_win_set_buf(state.orig_win, other_buf)

      assert.is_false(state.save())

      -- The original buffer is unchanged
      assert.are.same(orig_lines, vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false))
      -- The other buffer is unchanged
      assert.are.same({ "unrelated content" }, vim.api.nvim_buf_get_lines(other_buf, 0, -1, false))
      assert.is_false(state.closed)
      assert.are.same({ "edits", "from", "popup" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      state.cancel()

      pcall(vim.api.nvim_buf_delete, other_buf, { force = true })
    end)

    it("refuses to save when the original buffer was deleted", function()
      reset_to({
        "| H        | B |",
        "| -------- | - |",
        "| original | y |",
      })
      place_cursor_at(3, "original")

      local orig_buf = vim.api.nvim_get_current_buf()
      local state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "edits" })

      -- Replace the buffer in the window with a new scratch (so we can delete orig_buf),
      -- then nuke orig_buf entirely.
      local placeholder = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(state.orig_win, placeholder)
      pcall(vim.api.nvim_buf_delete, orig_buf, { force = true })

      assert.is_false(state.save())
      assert.is_false(state.closed)
      assert.are.same({ "edits" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      state.cancel()
    end)
  end)

  describe("stale save protection", function()
    local state
    local notifications
    local original_notify
    local keys = require("spec.helpers.insert_mode")

    before_each(function()
      notifications = {}
      original_notify = vim.notify
      vim.notify = function(message, level)
        table.insert(notifications, { message = message, level = level })
      end
      reset_to({ "BEFORE", "", "| A | B |", "| --- | --- |", "| old | keep |", "", "AFTER" })
      place_cursor_at(5, "old")
      state = cell_editor.open()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "new", "popup text" })
    end)

    after_each(function()
      state.cancel()
      vim.notify = original_notify
    end)

    ---@param message string
    ---@return nil
    local function assert_rejected(message)
      local source = vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false)
      local tick = vim.api.nvim_buf_get_changedtick(state.orig_buf)
      assert.is_false(state.save())
      assert.are.same(source, vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false))
      assert.equals(tick, vim.api.nvim_buf_get_changedtick(state.orig_buf))
      assert.is_false(state.closed)
      assert.is_true(vim.api.nvim_win_is_valid(state.scratch_win))
      assert.are.same({ "new", "popup text" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      assert.is_true(vim.bo[state.scratch_buf].modified)
      assert.matches(message, notifications[#notifications].message, 1, true)
      assert.equals(vim.log.levels.ERROR, notifications[#notifications].level)
    end

    local changes = {
      { name = "another source cell changes", start = 4, finish = 5, lines = { "| old | external edit |" } },
      { name = "the target cell changes", start = 4, finish = 5, lines = { "| external edit | keep |" } },
      { name = "text is inserted above the table", start = 0, finish = 0, lines = { "IMPORTANT NEW TEXT" } },
      { name = "text is deleted above the table", start = 0, finish = 2, lines = {} },
      { name = "the target row is deleted", start = 4, finish = 5, lines = {} },
      { name = "the table is replaced", start = 2, finish = 5, lines = { "REPLACEMENT TEXT" } },
      { name = "text outside the table changes", start = 6, finish = 7, lines = { "NEW AFTER" } },
    }

    for _, change in ipairs(changes) do
      it("rejects without changing source or losing popup text when " .. change.name, function()
        vim.api.nvim_buf_set_lines(state.orig_buf, change.start, change.finish, false, change.lines)
        assert_rejected("Source buffer changed")
      end)
    end

    it("retains popup text when the original window is closed", function()
      vim.api.nvim_set_current_win(state.orig_win)
      vim.cmd("vsplit")
      vim.api.nvim_set_current_win(state.scratch_win)
      vim.api.nvim_win_close(state.orig_win, true)
      assert_rejected("Original window was closed")
    end)

    it("retains popup text when the source becomes unmodifiable", function()
      vim.bo[state.orig_buf].modifiable = false
      assert_rejected("Original buffer is not modifiable")
      vim.bo[state.orig_buf].modifiable = true
    end)

    it("retains popup text when the source buffer is unloaded", function()
      local placeholder = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(state.orig_win, placeholder)
      vim.api.nvim_buf_delete(state.orig_buf, { unload = true, force = true })
      assert.is_false(vim.api.nvim_buf_is_loaded(state.orig_buf))
      assert.is_false(state.save())
      assert.is_false(state.closed)
      assert.are.same({ "new", "popup text" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      assert.matches("Original buffer was deleted or unloaded", notifications[#notifications].message, 1, true)
    end)

    it("rejects source edits made by an autocommand while returning to the original window", function()
      vim.api.nvim_create_autocmd("BufEnter", {
        buffer = state.orig_buf,
        once = true,
        callback = function()
          vim.api.nvim_buf_set_lines(state.orig_buf, 4, 5, false, { "| old | autocmd edit |" })
        end,
      })

      assert.is_false(state.save())
      assert.equals("| old | autocmd edit |", vim.api.nvim_buf_get_lines(state.orig_buf, 4, 5, false)[1])
      assert.is_false(state.closed)
      assert.equals(state.scratch_win, vim.api.nvim_get_current_win())
      assert.are.same({ "new", "popup text" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      assert.matches("Source buffer changed", notifications[#notifications].message, 1, true)
    end)

    it("does not write to a window selected by a source-entry autocommand", function()
      vim.api.nvim_set_current_win(state.orig_win)
      vim.cmd("new")
      local other_win = vim.api.nvim_get_current_win()
      local other_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(other_buf, 0, -1, false, { "UNRELATED", "", "", "", "" })
      vim.api.nvim_set_current_win(state.scratch_win)
      local source = vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false)
      vim.api.nvim_create_autocmd("BufEnter", {
        buffer = state.orig_buf,
        once = true,
        callback = function()
          vim.api.nvim_set_current_win(other_win)
        end,
      })

      assert.is_false(state.save())
      assert.are.same(source, vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false))
      assert.are.same({ "UNRELATED", "", "", "", "" }, vim.api.nvim_buf_get_lines(other_buf, 0, -1, false))
      assert.is_false(state.closed)
      assert.are.same({ "new", "popup text" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
      assert.matches("Source window lost focus", notifications[#notifications].message, 1, true)
      vim.api.nvim_win_close(other_win, true)
    end)

    for _, save_keys in ipairs({ ":write<CR>", "<CR>" }) do
      it("rejects stale source through real popup keys " .. save_keys, function()
        state.cancel()
        reset_to({ "| A | B |", "| --- | --- |", "| old | keep |" })
        place_cursor_at(3, "old")
        state = cell_editor.open()
        keys.press_normal("gg0Cnew<Esc><C-w>p", 1, 0)
        assert.equals(state.orig_buf, vim.api.nvim_get_current_buf())
        keys.press_normal("ggOIMPORTANT NEW TEXT<Esc>", 1, 0)
        local source = vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false)
        assert.equals("IMPORTANT NEW TEXT", source[1])
        vim.api.nvim_set_current_win(state.scratch_win)
        keys.press_normal(save_keys, 1, 0)
        assert.are.same(source, vim.api.nvim_buf_get_lines(state.orig_buf, 0, -1, false))
        assert.is_false(state.closed)
        assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
        assert.is_true(vim.bo[state.scratch_buf].modified)
        assert.matches("Source buffer changed", notifications[#notifications].message, 1, true)
      end)

      it("saves unchanged source through real popup keys " .. save_keys, function()
        keys.press_normal("gg0Cnew<Esc>" .. save_keys, 1, 0)
        assert.is_true(state.closed)
        assert.equals(state.orig_buf, vim.api.nvim_get_current_buf())
        assert.are.same({ "new<br>popup text", "keep" }, parser.get_table_at_cursor().cells[2])
      end)
    end
  end)

  describe("source writes and text revisions", function()
    local state
    local source_path
    local original_attach
    local keys = require("spec.helpers.insert_mode")

    before_each(function()
      state = nil
      original_attach = vim.api.nvim_buf_attach
      source_path = vim.fn.tempname() .. ".md"
      vim.api.nvim_buf_set_name(0, source_path)
      reset_to({ "| A | B |", "| --- | --- |", "| old | keep |" })
      place_cursor_at(3, "old")
    end)

    after_each(function()
      vim.api.nvim_buf_attach = original_attach
      if state then
        state.cancel()
      end
      vim.fn.delete(source_path)
    end)

    ---@return nil
    local function edit_popup()
      vim.api.nvim_buf_set_lines(state.scratch_buf, 0, -1, false, { "new" })
    end

    it("allows a source write without text changes followed by the real popup write", function()
      local source = vim.api.nvim_get_current_buf()
      local tick = vim.api.nvim_buf_get_changedtick(source)
      state = cell_editor.open()
      keys.press_normal("gg0Cnew<Esc><C-w>p", 1, 0)
      keys.press_normal(":write<CR>", 3, 0)
      assert.is_true(vim.api.nvim_buf_get_changedtick(source) > tick)
      assert.are.same({ "| A | B |", "| --- | --- |", "| old | keep |" }, vim.fn.readfile(source_path))
      vim.api.nvim_set_current_win(state.scratch_win)
      keys.press_normal(":write<CR>", 1, 0)
      assert.is_true(state.closed)
      assert.are.same({ "new", "keep" }, parser.get_table_at_cursor().cells[2])
    end)

    for _, event in ipairs({ "BufLeave", "BufEnter" }) do
      it("allows source autosave on " .. event .. " without text changes", function()
        local source = vim.api.nvim_get_current_buf()
        local tick = vim.api.nvim_buf_get_changedtick(source)
        vim.api.nvim_create_autocmd(event, {
          buffer = source,
          once = true,
          callback = function()
            vim.cmd("silent write")
          end,
        })
        state = cell_editor.open()
        edit_popup()
        assert.is_true(state.save())
        assert.is_true(vim.api.nvim_buf_get_changedtick(source) > tick)
        assert.are.same({ "new", "keep" }, parser.get_table_at_cursor().cells[2])
      end)
    end

    it("rejects source changes that happen while entering the popup", function()
      local source = vim.api.nvim_get_current_buf()
      vim.api.nvim_create_autocmd("BufLeave", {
        buffer = source,
        once = true,
        callback = function()
          vim.api.nvim_buf_set_lines(source, 2, 3, false, { "| old | source edit |" })
        end,
      })
      state = cell_editor.open()
      edit_popup()
      assert.is_false(state.save())
      assert.equals("| old | source edit |", vim.api.nvim_buf_get_lines(source, 2, 3, false)[1])
      assert.is_false(state.closed)
      assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
    end)

    it("rejects an edit followed by undo even when source text matches again", function()
      local source = vim.api.nvim_get_current_buf()
      local before = vim.api.nvim_buf_get_lines(source, 0, -1, false)
      vim.cmd("silent write")
      state = cell_editor.open()
      edit_popup()
      vim.api.nvim_set_current_win(state.orig_win)
      keys.press_normal("A changed<Esc>", 3, 0)
      keys.press_normal("u", 3, 0)
      assert.are.same(before, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      vim.api.nvim_set_current_win(state.scratch_win)
      assert.is_false(state.save())
      assert.is_false(state.closed)
      assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
    end)

    it("rejects a source reload even when the file contents are unchanged", function()
      vim.cmd("silent write")
      state = cell_editor.open()
      edit_popup()
      vim.api.nvim_win_call(state.orig_win, function()
        vim.cmd("edit!")
      end)
      assert.is_false(state.save())
      assert.is_false(state.closed)
      assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
    end)

    for _, close_method in ipairs({ "save", "cancel", "window" }) do
      it("stops source tracking after popup closure via " .. close_method, function()
        local callbacks
        local source = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_attach = function(buffer, send_buffer, opts)
          if buffer == source and opts.on_changedtick then
            callbacks = opts
          end
          return original_attach(buffer, send_buffer, opts)
        end
        state = cell_editor.open()
        assert.is_false(callbacks.on_changedtick())
        if close_method == "window" then
          vim.api.nvim_win_close(state.scratch_win, true)
        else
          assert.is_true(state[close_method]())
        end
        assert.is_true(state.closed)
        assert.is_true(callbacks.on_changedtick())
      end)
    end

    it("notifies instead of opening an untracked editor when buffer attachment fails", function()
      local original_notify = vim.notify
      local message
      vim.notify = function(text)
        message = text
      end
      vim.api.nvim_buf_attach = function()
        return false
      end
      state = cell_editor.open()
      vim.notify = original_notify
      assert.is_nil(state)
      assert.matches("Cannot track source buffer changes", message, 1, true)
    end)
  end)
end)
