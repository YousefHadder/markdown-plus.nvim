-- Tests for markdown-plus footnotes navigation module
describe("markdown-plus footnotes navigation", function()
  local nav = require("markdown-plus.footnotes.navigation")
  local parser = require("markdown-plus.footnotes.parser")
  local mocks = require("spec.helpers.mocks")
  local notify_spy, select_spy
  local stubs = {}

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "First line with [^1] ref",
      "Second line",
      "Third line with [^2] ref",
      "Fourth line",
      "[^1]: First definition",
      "[^2]: Second definition",
    })
    notify_spy = mocks.mock_notify()
  end)

  after_each(function()
    notify_spy.restore()
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

  -- Helper to register a stub for automatic cleanup
  local function stub(mod, fn_name, replacement)
    local s = mocks.stub_fn(mod, fn_name, replacement)
    table.insert(stubs, s)
    return s
  end

  describe("goto_definition", function()
    it("notifies when no footnote at cursor", function()
      stub(parser, "get_footnote_at_cursor", function()
        return nil
      end)

      nav.goto_definition()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No footnote under cursor"))
    end)

    it("notifies when already at definition", function()
      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "definition" }
      end)

      nav.goto_definition()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("Already at definition"))
    end)

    it("jumps to definition line", function()
      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_definition", function()
        return { line_num = 5, content = "[^1]: First definition" }
      end)

      vim.api.nvim_win_set_cursor(0, { 1, 17 })
      nav.goto_definition()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(5, cursor[1])
    end)

    it("notifies when no definition found", function()
      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "reference" }
      end)
      stub(parser, "find_definition", function()
        return nil
      end)

      nav.goto_definition()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No definition found"))
    end)
  end)

  describe("goto_reference", function()
    it("notifies when no footnote at cursor", function()
      stub(parser, "get_footnote_at_cursor", function()
        return nil
      end)

      nav.goto_reference()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No footnote under cursor"))
    end)

    it("jumps directly to single reference", function()
      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "definition" }
      end)
      stub(parser, "find_references", function()
        return { { line_num = 1, start_col = 17, end_col = 20 } }
      end)

      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      nav.goto_reference()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      assert.equals(16, cursor[2])
    end)

    it("shows select UI for multiple references", function()
      stub(parser, "get_footnote_at_cursor", function()
        return { id = "1", type = "definition" }
      end)
      stub(parser, "find_references", function()
        return {
          { line_num = 1, start_col = 17, end_col = 20 },
          { line_num = 3, start_col = 17, end_col = 20 },
        }
      end)
      select_spy = mocks.mock_select(1)

      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      nav.goto_reference()

      assert.equals(1, #select_spy.calls)
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      assert.equals(16, cursor[2])
    end)
  end)

  describe("next_footnote", function()
    it("notifies when no footnotes in document", function()
      stub(parser, "find_all_references", function()
        return {}
      end)

      nav.next_footnote()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No footnotes in document"))
    end)

    it("jumps to next footnote and wraps around", function()
      stub(parser, "find_all_references", function()
        return {
          { line_num = 1, start_col = 17, end_col = 20 },
          { line_num = 3, start_col = 17, end_col = 20 },
        }
      end)

      -- Start at first ref, should jump to second
      vim.api.nvim_win_set_cursor(0, { 1, 17 })
      nav.next_footnote()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1])
      assert.equals(16, cursor[2])

      -- Now past the last ref, should wrap to first
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      nav.next_footnote()

      cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      assert.equals(16, cursor[2])
      assert.is_truthy(notify_spy.calls[#notify_spy.calls].msg:find("Wrapped to first"))
    end)
  end)

  describe("prev_footnote", function()
    it("jumps to previous footnote and wraps around", function()
      stub(parser, "find_all_references", function()
        return {
          { line_num = 1, start_col = 17, end_col = 20 },
          { line_num = 3, start_col = 17, end_col = 20 },
        }
      end)

      -- Start at second ref, should jump to first
      vim.api.nvim_win_set_cursor(0, { 3, 17 })
      nav.prev_footnote()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      assert.equals(16, cursor[2])

      -- Now before the first ref, should wrap to last
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      nav.prev_footnote()

      cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1])
      assert.equals(16, cursor[2])
      assert.is_truthy(notify_spy.calls[#notify_spy.calls].msg:find("Wrapped to last"))
    end)
  end)
end)
