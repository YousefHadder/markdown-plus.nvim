---Test suite for the public list-context query API.
---Plugin authors and users compose their own `<BS>`/`<CR>`/`<Tab>` mappings around this, so the
---signature and return values are a stable contract.
---@diagnostic disable: undefined-field
local list = require("markdown-plus.list")
local markdown_plus = require("markdown-plus")

describe("markdown-plus list context API", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  ---Fill the buffer and place the cursor
  ---@param lines string[] Buffer contents
  ---@param row integer 1-indexed cursor row
  ---@param col integer 0-indexed cursor column
  ---@return nil
  local function fixture(lines, row, col)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, col })
  end

  it("is exposed on the list module and the plugin root", function()
    assert.are.equal("function", type(list.in_list_context))
    assert.are.equal("function", type(markdown_plus.in_list_context))
  end)

  it("reports a bullet item line as list context for every kind", function()
    fixture({ "- item" }, 1, 2)
    assert.is_true(list.in_list_context("backspace"))
    assert.is_true(list.in_list_context("indent"))
    assert.is_true(list.in_list_context("enter"))
  end)

  it("reports an ordered item line as list context", function()
    fixture({ "1. item" }, 1, 3)
    assert.is_true(list.in_list_context("backspace"))
  end)

  it("reports a checkbox item line as list context", function()
    fixture({ "- [ ] task" }, 1, 10)
    assert.is_true(list.in_list_context("indent"))
  end)

  -- `backspace` answers "would the marker be removed?", not "is this a list line?".
  -- `handle_backspace` defers mid-content, so a recipe keyed on the line alone would swallow
  -- backspaces that belong to a pairs plugin.
  it("reports mid-content as backspace context only in the marker zone", function()
    fixture({ "- item" }, 1, 6)
    assert.is_false(list.in_list_context("backspace"))
    -- Still a list line for the kinds that act line-wide
    assert.is_true(list.in_list_context("indent"))
    assert.is_true(list.in_list_context("enter"))
  end)

  it("reports the indentation zone as no backspace context", function()
    fixture({ "  - item" }, 1, 2)
    assert.is_false(list.in_list_context("backspace"))
  end)

  it("reports the start of checkbox content as backspace context", function()
    fixture({ "- [ ] task" }, 1, 6)
    assert.is_true(list.in_list_context("backspace"))
  end)

  it("reports a plain line as no list context for every kind", function()
    fixture({ "plain text" }, 1, 5)
    assert.is_false(list.in_list_context("backspace"))
    assert.is_false(list.in_list_context("indent"))
    assert.is_false(list.in_list_context("enter"))
  end)

  -- `enter` is the broadest kind: `handle_enter` also continues a list from a wrapped
  -- continuation line, whereas `handle_backspace`/`handle_tab` only act on the marker line.
  it("treats a continuation line as enter context but not backspace context", function()
    fixture({ "- item", "  wrapped text" }, 2, 5)
    assert.is_true(list.in_list_context("enter"))
    assert.is_false(list.in_list_context("backspace"))
    assert.is_false(list.in_list_context("indent"))
  end)

  it("defaults to the enter kind when none is given", function()
    fixture({ "- item", "  wrapped text" }, 2, 5)
    assert.is_true(list.in_list_context())

    fixture({ "plain text" }, 1, 0)
    assert.is_false(list.in_list_context())
  end)

  it("delegates from the plugin root to the same predicate", function()
    fixture({ "- item" }, 1, 2)
    assert.is_true(markdown_plus.in_list_context("backspace"))

    fixture({ "plain text" }, 1, 5)
    assert.is_false(markdown_plus.in_list_context("backspace"))
  end)

  it("notifies and returns false for an unknown kind", function()
    fixture({ "- item" }, 1, 6)
    local original_notify = vim.notify
    local messages = {}
    vim.notify = function(msg, level)
      table.insert(messages, { msg = msg, level = level })
    end

    local result = list.in_list_context("nonsense")
    vim.notify = original_notify

    assert.is_false(result)
    assert.are.equal(1, #messages)
    assert.is_truthy(messages[1].msg:match("^markdown%-plus:"))
    assert.are.equal(vim.log.levels.ERROR, messages[1].level)
  end)

  -- Every list handler is wrapped in `skip_in_codeblock`, so a `- item` inside a fence is
  -- *not* a context the handler acts in. The predicate must agree, or a recipe keyed on it
  -- routes the key into a handler that immediately hands it back.
  describe("inside a fenced code block", function()
    local FENCED = {
      "Intro",
      "```markdown",
      "- item",
      "  wrapped text",
      "```",
    }

    ---Run `fn` with `treesitter.is_in_fenced_code_block` stubbed to `value`.
    ---`true`/`false` exercise the treesitter path in `utils.is_in_code_block`; `nil` makes it
    ---fall through to the regex scan, which is the path Neovim takes without a markdown parser.
    ---@param value boolean|nil Stubbed treesitter verdict
    ---@param fn fun() Body to run under the stub
    ---@return nil
    local function with_treesitter(value, fn)
      local ts = require("markdown-plus.treesitter")
      local original = ts.is_in_fenced_code_block
      ts.is_in_fenced_code_block = function()
        return value
      end
      local ok, err = pcall(fn)
      ts.is_in_fenced_code_block = original
      assert(ok, err)
    end

    it("reports no context for any kind on the treesitter path", function()
      with_treesitter(true, function()
        fixture(FENCED, 3, 2)
        assert.is_false(list.in_list_context("backspace"))
        assert.is_false(list.in_list_context("indent"))
        assert.is_false(list.in_list_context("enter"))
      end)
    end)

    it("reports no context for any kind on the regex fallback path", function()
      with_treesitter(nil, function()
        fixture(FENCED, 3, 2)
        assert.is_false(list.in_list_context("backspace"))
        assert.is_false(list.in_list_context("indent"))
        assert.is_false(list.in_list_context("enter"))
      end)
    end)

    -- `enter` reaches back to a parent list item, so a continuation line inside the fence would
    -- otherwise report context from a marker line that is itself fenced.
    it("reports no enter context on a continuation line inside the fence", function()
      with_treesitter(nil, function()
        fixture(FENCED, 4, 4)
        assert.is_false(list.in_list_context("enter"))
      end)
      with_treesitter(true, function()
        fixture(FENCED, 4, 4)
        assert.is_false(list.in_list_context("enter"))
      end)
    end)

    it("still reports context on a list line outside the fence", function()
      local lines = { "```", "code", "```", "- item" }
      with_treesitter(nil, function()
        fixture(lines, 4, 2)
        assert.is_true(list.in_list_context("backspace"))
        assert.is_true(list.in_list_context("indent"))
        assert.is_true(list.in_list_context("enter"))
      end)
    end)

    it("reports no context in a real fenced buffer with no stubbing", function()
      fixture(FENCED, 3, 2)
      assert.is_false(list.in_list_context("backspace"))
      assert.is_false(list.in_list_context("indent"))
      assert.is_false(list.in_list_context("enter"))
    end)
  end)

  it("does not modify the buffer", function()
    fixture({ "- item" }, 1, 6)
    local tick = vim.api.nvim_buf_get_changedtick(0)
    list.in_list_context("enter")
    list.in_list_context("backspace")
    assert.are.equal(tick, vim.api.nvim_buf_get_changedtick(0))
  end)
end)
