---Test suite for markdown-plus.nvim keymap_fallback
---Tests lazy resolution of foreign (non-markdown-plus) mappings and their execution.
---@diagnostic disable: undefined-field
local fallback = require("markdown-plus.keymap_fallback")

---Feed pending typeahead so queued nvim_feedkeys calls are actually executed
---@return nil
local function flush()
  vim.api.nvim_feedkeys("", "x", false)
end

---Delete a mapping if it exists, ignoring "no such mapping" errors
---@param mode string
---@param lhs string
---@param opts? table
---@return nil
local function unmap(mode, lhs, opts)
  pcall(vim.keymap.del, mode, lhs, opts)
end

describe("markdown-plus keymap_fallback", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  after_each(function()
    unmap("n", "<F5>")
    unmap("n", "<F6>")
    unmap("i", "<F5>")
    unmap("n", "x")
    unmap("n", "<F5>", { buffer = true })
    unmap("i", "<BS>", { buffer = true })
    unmap("i", "<BS>")
    vim.cmd("bdelete!")
  end)

  describe("resolve", function()
    it("returns nil when no mapping exists", function()
      assert.is_nil(fallback.resolve("n", "<F5>"))
    end)

    it("resolves a global string rhs mapping", function()
      vim.keymap.set("n", "<F5>", "ix<Esc>")
      local target = fallback.resolve("n", "<F5>")
      assert.is_not_nil(target)
      assert.are.equal("ix<Esc>", target.rhs)
      assert.is_nil(target.callback)
      assert.is_false(target.expr)
      assert.is_true(target.noremap)
    end)

    it("resolves a global Lua callback mapping", function()
      vim.keymap.set("n", "<F5>", function() end)
      local target = fallback.resolve("n", "<F5>")
      assert.is_not_nil(target)
      assert.are.equal("function", type(target.callback))
      assert.is_false(target.expr)
    end)

    it("resolves a global expr callback with replace_keycodes enabled", function()
      vim.keymap.set("i", "<F5>", function()
        return "<BS>"
      end, { expr = true, replace_keycodes = true })
      local target = fallback.resolve("i", "<F5>")
      assert.is_not_nil(target)
      assert.is_true(target.expr)
      assert.is_true(target.replace_keycodes)
    end)

    it("resolves a global expr callback with replace_keycodes disabled", function()
      vim.keymap.set("i", "<F5>", function()
        return "x"
      end, { expr = true, replace_keycodes = false })
      local target = fallback.resolve("i", "<F5>")
      assert.is_not_nil(target)
      assert.is_true(target.expr)
      assert.is_false(target.replace_keycodes)
    end)

    it("prefers a buffer-local foreign mapping over a global one", function()
      vim.keymap.set("n", "<F5>", "iglobal<Esc>")
      vim.keymap.set("n", "<F5>", "ibuffer<Esc>", { buffer = true })
      local target = fallback.resolve("n", "<F5>")
      assert.is_not_nil(target)
      assert.are.equal("ibuffer<Esc>", target.rhs)
    end)

    it("excludes our own buffer-local <Plug>(MarkdownPlus...) default", function()
      vim.keymap.set("n", "<F5>", "iglobal<Esc>")
      vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
      local target = fallback.resolve("n", "<F5>")
      assert.is_not_nil(target)
      assert.are.equal("iglobal<Esc>", target.rhs)
    end)

    it("returns nil when the only mapping is our own default", function()
      vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
      assert.is_nil(fallback.resolve("n", "<F5>"))
    end)

    it("resolves lazily so mappings created after the first lookup are found", function()
      assert.is_nil(fallback.resolve("n", "<F5>"))
      vim.keymap.set("n", "<F5>", "ilate<Esc>")
      local target = fallback.resolve("n", "<F5>")
      assert.is_not_nil(target)
      assert.are.equal("ilate<Esc>", target.rhs)
    end)
  end)

  describe("run", function()
    it("invokes a resolved Lua callback", function()
      local called = false
      vim.keymap.set("n", "<F5>", function()
        called = true
      end)
      fallback.run("n", "<F5>")
      assert.is_true(called)
    end)

    it("feeds keys returned by an expr callback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.keymap.set("n", "<F5>", function()
        return "ihi<Esc>"
      end, { expr = true })
      fallback.run("n", "<F5>")
      flush()
      assert.are.equal("hi", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("replaces keycodes in expr results when replace_keycodes is set", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.keymap.set("n", "<F5>", function()
        return "ihi<Esc>"
      end, { expr = true, replace_keycodes = true })
      fallback.run("n", "<F5>")
      flush()
      assert.are.equal("hi", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("feeds a string rhs", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.keymap.set("n", "<F5>", "ix<Esc>")
      fallback.run("n", "<F5>")
      flush()
      assert.are.equal("x", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("feeds a remappable rhs so nested mappings still fire", function()
      local nested = false
      vim.keymap.set("n", "<F6>", function()
        nested = true
      end)
      vim.keymap.set("n", "<F5>", "<F6>", { remap = true })
      fallback.run("n", "<F5>")
      flush()
      assert.is_true(nested)
    end)

    it("feeds a noremap rhs without resolving nested mappings", function()
      local nested = false
      vim.keymap.set("n", "<F6>", function()
        nested = true
      end)
      vim.keymap.set("n", "<F5>", "<F6>")
      fallback.run("n", "<F5>")
      flush()
      assert.is_false(nested)
    end)

    it("feeds the raw key when no mapping is resolved", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abc" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      fallback.run("n", "x")
      flush()
      assert.are.equal("bc", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("notifies and does not throw when a callback errors", function()
      local original_notify = vim.notify
      local messages = {}
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      vim.keymap.set("n", "<F5>", function()
        error("boom")
      end)

      local ok = pcall(fallback.run, "n", "<F5>")
      vim.notify = original_notify

      assert.is_true(ok)
      assert.are.equal(1, #messages)
      assert.is_truthy(messages[1].msg:match("^markdown%-plus:"))
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)

    it("does not recurse when the resolved target feeds the same key back", function()
      local count = 0
      vim.keymap.set("n", "<F5>", function()
        count = count + 1
        return "<F5>"
      end, { expr = true, replace_keycodes = true })

      fallback.run("n", "<F5>")
      flush()

      -- The expr target is noremap, so the fed <F5> is not resolved through
      -- mappings again — the callback must run exactly once.
      assert.are.equal(1, count)
    end)

    it("degrades to the raw key when the resolved target calls run for the same key", function()
      -- A user may map a key straight to a markdown-plus handler, making the resolved
      -- target our own handler. Re-entry must feed the raw key instead of recursing.
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abc" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local count = 0
      vim.keymap.set("n", "x", function()
        count = count + 1
        fallback.run("n", "x")
      end)

      fallback.run("n", "x")
      flush()

      assert.are.equal(1, count)
      assert.are.equal("bc", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)
  end)
end)
