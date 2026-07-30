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
    fallback.reset()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  after_each(function()
    unmap("n", "<F5>")
    unmap("n", "<F6>")
    unmap("i", "<F5>")
    unmap("i", "<F6>")
    unmap("i", "<Plug>(MarkdownPlusFallbackSpec)")
    unmap("n", "x")
    unmap("n", "<F5>", { buffer = true })
    unmap("i", "<F5>", { buffer = true })
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

    -- Vanilla Neovim keeps a pending count across an expr mapping and applies it to the keys
    -- the mapping returns, so `3o` through a foreign `o` expr map opens three lines. Our
    -- mapping consumes the count, so it has to be re-prefixed onto the produced keys.
    it("applies opts.count to keys produced by a noremap expr target", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local calls = 0
      vim.keymap.set("n", "<F5>", function()
        calls = calls + 1
        return "ox<Esc>"
      end, { expr = true, replace_keycodes = true })

      fallback.run("n", "<F5>", { count = 3 })
      flush()

      assert.are.equal(1, calls)
      assert.are.same({ "plain text", "x", "x", "x" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("applies opts.count to a noremap string rhs target", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.keymap.set("n", "<F5>", "ox<Esc>")

      fallback.run("n", "<F5>", { count = 3 })
      flush()

      assert.are.same({ "plain text", "x", "x", "x" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("keeps opts.count when the target routes back into markdown-plus", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdef" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.keymap.set("n", "x", function()
        return "<Plug>(MarkdownPlusListBackspace)"
      end, { expr = true, replace_keycodes = true })

      fallback.run("n", "x", { count = 3 })
      flush()

      -- The bounce degrades to the raw key, which replaces the whole target execution:
      -- `3x` must still delete three characters.
      assert.are.equal("def", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    -- Some of our defaults sit on keys that mean nothing on their own — table navigation's
    -- `<A-l>` is inert in insert mode, so degrading to the literal lhs would swallow the
    -- keypress. `opts.fallback_key` names the key that degradation should feed instead, so
    -- every terminal path (no target, bounce, target error) ends in real behavior.
    describe("opts.fallback_key", function()
      before_each(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdef" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
      end)

      it("feeds the substitute key when no target resolves", function()
        fallback.run("n", "<F5>", { fallback_key = "x" })
        flush()

        assert.are.equal("bcdef", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)

      it("applies opts.count to the substitute key", function()
        fallback.run("n", "<F5>", { count = 3, fallback_key = "x" })
        flush()

        assert.are.equal("def", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)

      it("feeds the substitute key when the target routes back into markdown-plus", function()
        -- copilot/blink shape: the target hands our own `<Plug>` back. Without the option the
        -- chain terminates in the inert raw lhs; with it, the substitute key runs.
        vim.keymap.set("n", "<F5>", function()
          return "<Plug>(MarkdownPlusListBackspace)"
        end, { expr = true, replace_keycodes = true })

        fallback.run("n", "<F5>", { fallback_key = "x" })
        flush()

        assert.are.equal("bcdef", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)

      it("feeds the substitute key when the resolved target errors", function()
        local original_notify = vim.notify
        local messages = {}
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        vim.keymap.set("n", "<F5>", function()
          error("target exploded")
        end)

        fallback.run("n", "<F5>", { fallback_key = "x" })
        flush()
        vim.notify = original_notify

        assert.are.equal(1, #messages)
        assert.are.equal("bcdef", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)

      it("feeds the substitute key when the target re-enters run for the same key", function()
        local calls = 0
        vim.keymap.set("n", "<F5>", function()
          calls = calls + 1
          fallback.run("n", "<F5>", { fallback_key = "x" })
        end)

        fallback.run("n", "<F5>", { fallback_key = "x" })
        flush()

        assert.are.equal(1, calls)
        assert.are.equal("bcdef", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)

      it("still runs a resolved target instead of the substitute key", function()
        local calls = 0
        vim.keymap.set("n", "<F5>", function()
          calls = calls + 1
        end)

        fallback.run("n", "<F5>", { fallback_key = "x" })
        flush()

        assert.are.equal(1, calls)
        assert.are.equal("abcdef", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      end)
    end)
  end)

  -- Regression: a *remappable* foreign mapping whose keys start with its own lhs (the
  -- LuaSnip-style `<Tab>` pattern) used to loop forever, because the keys we fed were
  -- re-resolved through our own buffer-local default in a later event-loop turn.
  describe("remappable targets that reproduce their own lhs", function()
    ---Mirror the real plugin wiring: buffer-local default → `<Plug>` → `fallback.run`
    ---@param state table Mutable state table; `state.calls` counts handler invocations
    ---@return nil
    local function install_our_default(state)
      vim.keymap.set("i", "<Plug>(MarkdownPlusFallbackSpec)", function()
        state.calls = state.calls + 1
        -- Circuit breaker: without it an unfixed recursion would spin the event loop
        -- forever and hang the suite instead of failing with a readable assertion.
        if state.calls > 1 then
          return
        end
        fallback.run("i", "<F5>")
      end)
      vim.keymap.set("i", "<F5>", "<Plug>(MarkdownPlusFallbackSpec)", { buffer = true, remap = true })
    end

    ---Type `keys` and drain the typeahead
    ---@param keys string Key notation (e.g. "i<F5><Esc>")
    ---@return nil
    local function press(keys)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
    end

    before_each(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end)

    it("terminates when a remappable expr target returns its own lhs", function()
      local state = { calls = 0 }
      install_our_default(state)
      vim.keymap.set("i", "<F5>", function()
        return "<F5>"
      end, { expr = true, remap = true, replace_keycodes = true })

      press("i<F5><Esc>")

      assert.are.equal(1, state.calls)
      -- The lhs prefix is fed noremap, so it reaches insert mode unmapped and degrades to
      -- the literal key instead of being resolved through our default a second time.
      assert.are.equal("<F5>", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("feeds the lhs prefix noremap but keeps the remainder remappable", function()
      local state = { calls = 0 }
      local remainder_fired = 0
      install_our_default(state)
      vim.keymap.set("i", "<F6>", function()
        remainder_fired = remainder_fired + 1
      end)
      vim.keymap.set("i", "<F5>", function()
        return "<F5><F6>"
      end, { expr = true, remap = true, replace_keycodes = true })

      press("i<F5><Esc>")

      assert.are.equal(1, state.calls)
      assert.are.equal(1, remainder_fired)
    end)

    it("terminates when a remappable string rhs equals its own lhs", function()
      local state = { calls = 0 }
      install_our_default(state)
      vim.keymap.set("i", "<F5>", "<F5>", { remap = true })

      press("i<F5><Esc>")

      assert.are.equal(1, state.calls)
      -- The lhs prefix is fed noremap, so it reaches insert mode unmapped and degrades to
      -- the literal key instead of being resolved through our default a second time.
      assert.are.equal("<F5>", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("still resolves a remappable rhs that does not start with the lhs", function()
      local state = { calls = 0 }
      local nested = 0
      install_our_default(state)
      vim.keymap.set("i", "<F6>", function()
        nested = nested + 1
      end)
      vim.keymap.set("i", "<F5>", "<F6>", { remap = true })

      press("i<F5><Esc>")

      assert.are.equal(1, state.calls)
      assert.are.equal(1, nested)
    end)
  end)

  -- Regression: completion plugins *replace* our buffer-local default and keep the mapping
  -- they displaced as their own fallback. Pressing the key then bounced foreign → our
  -- `<Plug>` → our handler → fallback → foreign → … forever, freezing the editor.
  -- blink.cmp (`keymap/fallback.lua`) and copilot.lua (`register_keymap_with_passthrough`)
  -- are the two real-world shapes; both are covered here.
  describe("targets that route back into markdown-plus", function()
    local OUR_PLUG = "<Plug>(MarkdownPlusFallbackSpec)"

    ---Install our handler behind a `<Plug>` mapping, mirroring the real plugin wiring
    ---@param state table Mutable state table; `state.calls` counts handler invocations
    ---@return nil
    local function install_our_handler(state)
      vim.keymap.set("i", OUR_PLUG, function()
        state.calls = state.calls + 1
        -- Circuit breaker: without the fix this recursion spins the event loop forever and
        -- would hang the suite instead of failing with a readable assertion.
        if state.calls > 4 then
          return
        end
        fallback.run("i", "<F5>")
      end)
    end

    ---Type `keys` and drain the typeahead
    ---@param keys string Key notation (e.g. "i<F5><Esc>")
    ---@return nil
    local function press(keys)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
    end

    before_each(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end)

    it("degrades to the raw key when an expr target returns our own <Plug>", function()
      -- blink.cmp shape: buffer-local, expr, noremap, replace_keycodes = false. Its
      -- `fallback` command returns the keycodes of the mapping it displaced — ours.
      local state = { calls = 0, foreign = 0 }
      install_our_handler(state)
      vim.api.nvim_buf_set_keymap(0, "i", "<F5>", "", {
        callback = function()
          state.foreign = state.foreign + 1
          return vim.api.nvim_replace_termcodes(OUR_PLUG, true, true, true)
        end,
        expr = true,
        noremap = true,
        replace_keycodes = false,
        silent = true,
      })

      press("i<F5><Esc>")

      assert.are.equal(1, state.calls)
      assert.are.equal(2, state.foreign)
      -- The bounce terminates in the raw key: `<F5>` has no insert-mode meaning of its own, so
      -- it degrades to its literal notation in the buffer. Pins that the raw key really landed
      -- instead of the chain dying silently.
      assert.are.equal("<F5>", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)

    it("degrades to the raw key when a target feeds our <Plug> into the typeahead", function()
      -- copilot.lua shape: buffer-local expr passthrough that feeds the displaced mapping
      -- itself and returns <Ignore>, so the bounce arrives in a later event-loop turn.
      local state = { calls = 0 }
      install_our_handler(state)
      vim.keymap.set("i", "<F5>", function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(OUR_PLUG, true, false, true), "i", true)
        return "<Ignore>"
      end, { expr = true, replace_keycodes = true, silent = true, buffer = true })

      press("i<F5><Esc>")

      -- One real pass plus a single bounce that the in-flight guard terminates.
      assert.are.equal(2, state.calls)
    end)

    it("still runs the foreign target on a repeat press within the same burst", function()
      local state = { calls = 0 }
      local foreign = 0
      install_our_handler(state)
      vim.keymap.set("i", "<F5>", "<Plug>(MarkdownPlusFallbackSpec)", { buffer = true, remap = true })
      vim.keymap.set("i", "<F5>", function()
        foreign = foreign + 1
        return "x"
      end, { expr = true, replace_keycodes = true })

      press("i<F5><F5><Esc>")

      assert.are.equal(2, foreign)
      assert.are.equal("xx", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
    end)
  end)
end)
