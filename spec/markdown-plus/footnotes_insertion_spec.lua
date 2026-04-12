-- Tests for markdown-plus footnotes insertion module
describe("markdown-plus footnotes insertion", function()
  local insertion = require("markdown-plus.footnotes.insertion")
  local parser = require("markdown-plus.footnotes.parser")
  local mocks = require("spec.helpers.mocks")
  local notify_spy, input_spy, select_spy
  local stubs = {}

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    notify_spy = mocks.mock_notify()
    insertion.set_confirm_delete(false) -- disable confirmation for most tests
  end)

  after_each(function()
    notify_spy.restore()
    if input_spy then
      input_spy.restore()
      input_spy = nil
    end
    if select_spy then
      select_spy.restore()
      select_spy = nil
    end
    for _, s in ipairs(stubs) do
      s.restore()
    end
    stubs = {}
    vim.cmd("bdelete!")
  end)

  -- Helper to track stubs for automatic cleanup
  local function stub(mod, fn_name, replacement)
    local s = mocks.stub_fn(mod, fn_name, replacement)
    table.insert(stubs, s)
    return s
  end

  describe("insert_footnote", function()
    it("does nothing when user cancels input", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      stub(parser, "get_next_numeric_id", function()
        return "1"
      end)

      -- nil response simulates user cancelling
      input_spy = mocks.mock_input({ nil })
      insertion.insert_footnote()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("Some text here", lines[1])
    end)

    it("shows error for invalid footnote ID", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      stub(parser, "get_next_numeric_id", function()
        return "1"
      end)

      input_spy = mocks.mock_input({ "invalid!@#" })
      insertion.insert_footnote()

      assert.is_true(#notify_spy.calls > 0, "Expected a notification")
      local found_error = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg and call.msg:match("Invalid") and call.level == vim.log.levels.ERROR then
          found_error = true
          break
        end
      end
      assert.is_true(found_error, "Expected error notification about invalid ID")
    end)

    it("creates reference and footnotes section for new footnote", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      stub(parser, "get_next_numeric_id", function()
        return "1"
      end)
      stub(parser, "find_definition", function()
        return nil
      end)
      stub(parser, "find_footnotes_section", function()
        return nil
      end)
      stub(parser, "parse_definition", function()
        return nil
      end)
      stub(parser, "get_definition_range", function()
        return nil, nil
      end)

      input_spy = mocks.mock_input({ "1" })
      insertion.insert_footnote()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      -- Line 1 should contain the reference [^1]
      assert.is_truthy(lines[1]:find("%[%^1%]"), "Expected [^1] reference in line 1")

      -- Buffer should contain the footnotes section header and definition
      local full_text = table.concat(lines, "\n")
      assert.is_truthy(full_text:find("## Footnotes"), "Expected footnotes section header")
      assert.is_truthy(full_text:find("%[%^1%]: "), "Expected footnote definition")
    end)

    it("inserts reference only when definition already exists", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      stub(parser, "get_next_numeric_id", function()
        return "1"
      end)
      stub(parser, "find_definition", function()
        return { line_num = 5, content = "existing" }
      end)

      input_spy = mocks.mock_input({ "1" })
      insertion.insert_footnote()

      -- Should notify about existing footnote
      local found_existing = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg and call.msg:match("existing footnote") then
          found_existing = true
          break
        end
      end
      assert.is_true(found_existing, "Expected notification about existing footnote")
    end)
  end)

  describe("edit_footnote", function()
    it("notifies when no footnote at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Plain text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      stub(parser, "get_footnote_at_cursor", function()
        return nil
      end)

      insertion.edit_footnote()

      local found_warn = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg and call.msg:match("No footnote under cursor") then
          found_warn = true
          break
        end
      end
      assert.is_true(found_warn, "Expected 'No footnote under cursor' notification")
    end)

    it("notifies when no definition found", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Text [^1] here" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_definition", function()
        return nil
      end)

      insertion.edit_footnote()

      local found_warn = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg and call.msg:match("No definition found") then
          found_warn = true
          break
        end
      end
      assert.is_true(found_warn, "Expected 'No definition found' notification")
    end)

    it("jumps to definition line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text [^1] here",
        "",
        "[^1]: Some definition",
        "",
        "More text",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 3, content = "Some definition" }
      end)

      insertion.edit_footnote()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1], "Expected cursor to move to definition at line 3")
    end)
  end)

  describe("delete_footnote", function()
    it("notifies when no footnote at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      stub(parser, "get_footnote_at_cursor", function()
        return nil
      end)

      insertion.delete_footnote()

      local found_warn = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg and call.msg:match("No footnote under cursor") then
          found_warn = true
          break
        end
      end
      assert.is_true(found_warn, "Expected 'No footnote under cursor' notification")
    end)

    it("deletes reference and definition", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text [^1] here",
        "Second line",
        "",
        "## Footnotes",
        "[^1]: Definition",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_references", function()
        return { { line_num = 1, start_col = 6, end_col = 9 } }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 5 }
      end)
      stub(parser, "get_definition_range", function()
        return 5, 5
      end)

      insertion.delete_footnote()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Reference should be removed from line 1
      assert.is_falsy(lines[1]:find("%[%^1%]"), "Expected reference [^1] to be removed")
      assert.is_truthy(lines[1]:find("Text  here") or lines[1]:find("Text here"), "Expected text to remain")
    end)

    it("deletes when user confirms with Yes", function()
      insertion.set_confirm_delete(true)

      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text [^1] here",
        "",
        "[^1]: Definition",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_references", function()
        return { { line_num = 1, start_col = 6, end_col = 9 } }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 3 }
      end)
      stub(parser, "get_definition_range", function()
        return 3, 3
      end)

      select_spy = mocks.mock_select(1) -- Choose "Yes"
      insertion.delete_footnote()

      -- Verify deletion happened
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_falsy(table.concat(lines, "\n"):find("%[%^1%]"), "Expected footnote to be deleted")

      -- Verify select was called
      assert.equals(1, #select_spy.calls, "Expected vim.ui.select to be called")
    end)

    it("does not delete when user cancels confirmation", function()
      insertion.set_confirm_delete(true)

      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text [^1] here",
        "",
        "[^1]: Definition",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_references", function()
        return { { line_num = 1, start_col = 6, end_col = 9 } }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 3 }
      end)
      stub(parser, "get_definition_range", function()
        return 3, 3
      end)

      select_spy = mocks.mock_select(2) -- Choose "No"
      insertion.delete_footnote()

      -- Buffer should be unchanged
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Text [^1] here", lines[1])
      assert.equals("[^1]: Definition", lines[3])
    end)
  end)

  describe("config setters", function()
    it("set_section_header changes the header text", function()
      insertion.set_section_header("Notes")

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      stub(parser, "get_next_numeric_id", function()
        return "1"
      end)
      stub(parser, "find_definition", function()
        return nil
      end)
      stub(parser, "find_footnotes_section", function()
        return nil
      end)
      stub(parser, "parse_definition", function()
        return nil
      end)
      stub(parser, "get_definition_range", function()
        return nil, nil
      end)

      input_spy = mocks.mock_input({ "1" })
      insertion.insert_footnote()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local full_text = table.concat(lines, "\n")
      assert.is_truthy(full_text:find("## Notes"), "Expected '## Notes' section header")

      -- Reset to default for other tests
      insertion.set_section_header("Footnotes")
    end)

    it("set_confirm_delete(nil) defaults to true", function()
      insertion.set_confirm_delete(nil) -- should default to true

      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text [^1] here",
        "",
        "[^1]: Definition",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_references", function()
        return { { line_num = 1, start_col = 6, end_col = 9 } }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 3 }
      end)
      stub(parser, "get_definition_range", function()
        return 3, 3
      end)

      -- mock_select with nil (cancel) — confirm_delete=true means select is shown
      select_spy = mocks.mock_select(nil)
      insertion.delete_footnote()

      -- vim.ui.select should have been called (confirmation prompt appeared)
      assert.equals(1, #select_spy.calls, "Expected vim.ui.select to be called when confirm_delete defaults to true")

      -- Buffer should be unchanged since we cancelled
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Text [^1] here", lines[1])
    end)
  end)
end)
