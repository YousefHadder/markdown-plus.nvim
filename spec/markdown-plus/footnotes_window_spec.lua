-- Tests for markdown-plus footnotes window module
describe("markdown-plus footnotes window", function()
  local window = require("markdown-plus.footnotes.window")
  local parser = require("markdown-plus.footnotes.parser")
  local mocks = require("spec.helpers.mocks")
  local notify_spy, select_spy, parser_stub, cmd_spy

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "line 1 with some extra text here",
      "line 2 with some extra text here",
      "line 3 with some extra text here",
      "line 4 with some extra text here",
      "line 5 with some extra text here",
    })
    notify_spy = mocks.mock_notify()
  end)

  after_each(function()
    notify_spy.restore()
    if select_spy then
      select_spy.restore()
    end
    if parser_stub then
      parser_stub.restore()
    end
    if cmd_spy then
      cmd_spy.restore()
    end
    vim.cmd("bdelete!")
  end)

  describe("empty footnotes list", function()
    it("notifies when no footnotes in document", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {}
      end)

      window.open_footnotes_window()

      assert.equals(1, #notify_spy.calls)
      assert.truthy(notify_spy.calls[1].msg:match("No footnotes in document"))
      assert.equals(vim.log.levels.INFO, notify_spy.calls[1].level)
    end)
  end)

  describe("format_footnote_line", function()
    it("shows space icon for normal footnote with definition and references", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "1",
            definition = { line_num = 3, content = "Footnote text" },
            references = { { line_num = 1, start_col = 5 } },
          },
        }
      end)

      select_spy = mocks.mock_select(nil) -- cancel to avoid cursor changes

      window.open_footnotes_window()

      assert.equals(1, #select_spy.calls)
      local items = select_spy.calls[1].items
      assert.equals(1, #items)

      local display = items[1].display
      -- Space icon (not ✗ or ⚠), footnote id, content, ref count
      assert.truthy(display:match("^  %[%^1%]"))
      assert.truthy(display:match("Footnote text"))
      assert.truthy(display:match("1 ref"))
    end)

    it("shows ⚠ icon for orphan footnote (definition but no references)", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "orphan",
            definition = { line_num = 4, content = "Orphaned note" },
            references = {},
          },
        }
      end)

      select_spy = mocks.mock_select(nil)

      window.open_footnotes_window()

      local display = select_spy.calls[1].items[1].display
      assert.truthy(display:match("⚠ %[%^orphan%]"))
      assert.truthy(display:match("Orphaned note"))
      assert.truthy(display:match("0 refs"))
    end)

    it("shows ✗ icon for footnote with references but no definition", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "missing",
            definition = nil,
            references = { { line_num = 2, start_col = 10 } },
          },
        }
      end)

      select_spy = mocks.mock_select(nil)

      window.open_footnotes_window()

      local display = select_spy.calls[1].items[1].display
      assert.truthy(display:match("✗ %[%^missing%]"))
      assert.truthy(display:match("%(no definition%)"))
      assert.truthy(display:match("1 ref"))
    end)
  end)

  describe("select callback", function()
    it("jumps to definition line when footnote has a definition", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "1",
            definition = { line_num = 3, content = "Footnote text" },
            references = { { line_num = 1, start_col = 5 } },
          },
        }
      end)

      select_spy = mocks.mock_select(1) -- select the first item
      cmd_spy = mocks.mock_cmd(false)

      window.open_footnotes_window()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1])
      assert.equals(0, cursor[2])
    end)

    it("jumps to first reference when footnote has no definition", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "nodef",
            definition = nil,
            references = { { line_num = 2, start_col = 10 }, { line_num = 4, start_col = 1 } },
          },
        }
      end)

      select_spy = mocks.mock_select(1)
      cmd_spy = mocks.mock_cmd(false)

      window.open_footnotes_window()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, cursor[1])
      assert.equals(9, cursor[2]) -- start_col - 1
    end)

    it("does nothing when selection is cancelled", function()
      parser_stub = mocks.stub_fn(parser, "get_all_footnotes", function()
        return {
          {
            id = "1",
            definition = { line_num = 4, content = "Some note" },
            references = { { line_num = 1, start_col = 5 } },
          },
        }
      end)

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      select_spy = mocks.mock_select(nil) -- cancel

      window.open_footnotes_window()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      assert.equals(0, cursor[2])
    end)
  end)
end)
