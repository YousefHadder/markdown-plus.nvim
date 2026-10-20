-- Tests for markdown-plus smart paste module
describe("markdown-plus smart paste", function()
  local smart_paste = require("markdown-plus.links.smart_paste")

  describe("helper functions", function()
    describe("_clamp_timeout", function()
      it("returns default 5 for nil", function()
        assert.equals(5, smart_paste._clamp_timeout(nil))
      end)

      it("clamps low values to 1", function()
        assert.equals(1, smart_paste._clamp_timeout(0))
      end)

      it("clamps high values to 30", function()
        assert.equals(30, smart_paste._clamp_timeout(100))
      end)
    end)

    describe("_truncate_title", function()
      it("preserves short titles", function()
        assert.equals("hello", smart_paste._truncate_title("hello"))
      end)

      it("truncates long titles ending with ellipsis", function()
        local long_title = string.rep("x", 400)
        local result = smart_paste._truncate_title(long_title)
        assert.equals(300, #result)
        assert.equals("...", result:sub(-3))
      end)
    end)

    describe("_url_needs_brackets", function()
      it("returns false for normal URL", function()
        assert.is_false(smart_paste._url_needs_brackets("https://example.com"))
      end)

      it("returns true for URL with parens", function()
        assert.is_true(smart_paste._url_needs_brackets("https://example.com/path(1)"))
      end)
    end)

    describe("_format_url_for_markdown", function()
      it("wraps URL with special chars in angle brackets", function()
        assert.equals("<https://url (1)>", smart_paste._format_url_for_markdown("https://url (1)"))
      end)
    end)
  end)

  -- ===========================================================================
  -- Integration tests for smart_paste() and its internal helpers
  -- ===========================================================================

  describe("smart_paste() integration", function()
    local http_fetch = require("markdown-plus.links.http_fetch")
    local mocks = require("spec.helpers.mocks")
    local notify_spy, schedule_spy, input_spy
    local orig_getreg, orig_fetch
    local enabled_config = { links = { smart_paste = { enabled = true, timeout = 5 } } }

    --- Override vim.fn.getreg so the + and unnamed registers return `url`
    local function mock_clipboard(url)
      vim.fn.getreg = function(reg)
        if reg == "+" then
          return url
        end
        if reg == '"' then
          return ""
        end
        return ""
      end
    end

    before_each(function()
      vim.cmd("enew")
      vim.bo.filetype = "markdown"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Hello world" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      notify_spy = mocks.mock_notify()
      orig_getreg = vim.fn.getreg
      orig_fetch = http_fetch.fetch_html_async
    end)

    after_each(function()
      notify_spy.restore()
      if schedule_spy then
        schedule_spy.restore()
        schedule_spy = nil
      end
      if input_spy then
        input_spy.restore()
        input_spy = nil
      end
      vim.fn.getreg = orig_getreg
      http_fetch.fetch_html_async = orig_fetch
      pcall(vim.cmd, "bdelete!")
    end)

    it("notifies when feature is disabled", function()
      smart_paste.setup({})
      smart_paste.smart_paste()
      assert.equals(1, #notify_spy.calls)
      assert.truthy(notify_spy.calls[1].msg:find("not enabled"))
    end)

    it("notifies when no URL in clipboard", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("")
      smart_paste.smart_paste()
      assert.equals(1, #notify_spy.calls)
      assert.truthy(notify_spy.calls[1].msg:find("No URL in clipboard"))
    end)

    it("notifies when URL is blocked", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("http://localhost:8080/admin")
      smart_paste.smart_paste()
      assert.equals(1, #notify_spy.calls)
      assert.truthy(notify_spy.calls[1].msg:find("Refusing"))
    end)

    it("notifies when buffer is not modifiable", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("https://example.com")
      vim.bo.modifiable = false
      smart_paste.smart_paste()
      vim.bo.modifiable = true
      assert.equals(1, #notify_spy.calls)
      assert.truthy(notify_spy.calls[1].msg:find("not modifiable"))
    end)

    it("inserts markdown link on successful fetch", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("https://example.com")
      schedule_spy = mocks.mock_schedule()
      http_fetch.fetch_html_async = function(_, _, callback)
        callback("<html><title>My Page</title></html>", nil)
      end

      smart_paste.smart_paste()
      schedule_spy.flush()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.truthy(line:find("%[My Page%]%(https://example%.com%)"))
    end)

    it("prompts for title on fetch error", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("https://example.com")
      schedule_spy = mocks.mock_schedule()
      http_fetch.fetch_html_async = function(_, _, callback)
        callback(nil, "timeout")
      end

      smart_paste.smart_paste()
      -- Set up input mock BEFORE flushing (flush triggers prompt_for_title)
      input_spy = mocks.mock_input({ "Custom Title" })
      schedule_spy.flush()

      -- Should have notified about the fetch failure
      local found_failed = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg:find("Failed to fetch") then
          found_failed = true
          break
        end
      end
      assert.is_true(found_failed, "Expected 'Failed to fetch' notification")

      -- vim.ui.input callback schedules another vim.schedule callback
      schedule_spy.flush()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.truthy(line:find("%[Custom Title%]%(https://example%.com%)"))
    end)

    it("prompts when no title found in HTML", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("https://example.com")
      schedule_spy = mocks.mock_schedule()
      http_fetch.fetch_html_async = function(_, _, callback)
        callback("<html><body>no title tag</body></html>", nil)
      end

      smart_paste.smart_paste()
      input_spy = mocks.mock_input({ "Manual Title" })
      schedule_spy.flush()

      local found_msg = false
      for _, call in ipairs(notify_spy.calls) do
        if call.msg:find("Could not extract title") then
          found_msg = true
          break
        end
      end
      assert.is_true(found_msg, "Expected 'Could not extract title' notification")

      schedule_spy.flush()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.truthy(line:find("%[Manual Title%]%(https://example%.com%)"))
    end)

    it("inserts plain URL when user cancels title prompt", function()
      smart_paste.setup(enabled_config)
      mock_clipboard("https://example.com")
      schedule_spy = mocks.mock_schedule()
      http_fetch.fetch_html_async = function(_, _, callback)
        callback(nil, "connection refused")
      end

      smart_paste.smart_paste()
      -- Empty queue → mock returns nil (user cancelled)
      input_spy = mocks.mock_input({})
      schedule_spy.flush()
      schedule_spy.flush()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.truthy(line:find("https://example.com", 1, true))
      -- Should NOT be wrapped in markdown link syntax
      assert.falsy(line:match("%[.+%]%(https://example%.com%)"))
    end)

    describe("pending placeholder edits", function()
      local insert_mode = require("spec.helpers.insert_mode")
      local url = "https://example.com/"
      local fetch_callback

      ---Read the byte column immediately after the pending placeholder.
      ---@return integer
      local function placeholder_end()
        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        return assert(line:find("SUFFIX", 1, true)) - 1
      end

      before_each(function()
        smart_paste.setup(enabled_config)
        mock_clipboard(url)
        schedule_spy = mocks.mock_schedule()
        fetch_callback = nil
        http_fetch.fetch_html_async = function(_, _, callback)
          fetch_callback = callback
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "prefix SUFFIX" })
        vim.api.nvim_win_set_cursor(0, { 1, 7 })
        smart_paste.smart_paste()
        assert.is_function(fetch_callback)
      end)

      for _, completion in ipairs({
        { name = "fetched title", html = "<title>Page</title>", result = "[Page](" .. url .. ")" },
        {
          name = "manual title after fetch failure",
          err = "timeout",
          responses = { "Manual Title" },
          result = "[Manual Title](" .. url .. ")",
        },
        {
          name = "manual title without page title",
          html = "<html><body>No title</body></html>",
          responses = { "Manual Title" },
          result = "[Manual Title](" .. url .. ")",
        },
        { name = "cancelled title prompt", err = "timeout", responses = {}, result = url },
      }) do
        describe(completion.name, function()
          ---Finish the held request and any title-input callbacks.
          ---@return nil
          local function complete()
            input_spy = mocks.mock_input(completion.responses or {})
            fetch_callback(completion.html, completion.err)
            schedule_spy.flush()
            schedule_spy.flush()
          end

          it("completes an untouched placeholder", function()
            complete()
            assert.same({ "prefix " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("preserves API insertion at the ending boundary", function()
            local stop = placeholder_end()
            vim.api.nvim_buf_set_text(0, 0, stop, 0, stop, { "NEW TEXT" })
            complete()
            assert.same(
              { "prefix " .. completion.result .. "NEW TEXTSUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("preserves real insert-mode typing at the ending boundary", function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local pending = vim.api.nvim_get_current_line()
            local result = insert_mode.press("NEW TEXT", cursor[1], cursor[2])
            assert.same({ (pending:gsub("SUFFIX$", "NEW TEXTSUFFIX")) }, result.lines)
            complete()
            assert.same(
              { "prefix " .. completion.result .. "NEW TEXTSUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("preserves insertion at the starting boundary", function()
            vim.api.nvim_buf_set_text(0, 0, 7, 0, 7, { "BEFORE" })
            complete()
            assert.same(
              { "prefix BEFORE" .. completion.result .. "SUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("preserves a newline at the ending boundary", function()
            local stop = placeholder_end()
            vim.api.nvim_buf_set_text(0, 0, stop, 0, stop, { "", "NEW TEXT" })
            complete()
            assert.same(
              { "prefix " .. completion.result, "NEW TEXTSUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("does not recreate a deleted placeholder", function()
            vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), {})
            complete()
            assert.same({ "prefix SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("does not recreate a deleted source line", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
            complete()
            assert.same({ "" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("preserves a user replacement", function()
            vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), { "custom text" })
            complete()
            assert.same({ "prefix custom textSUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("preserves edits inside the placeholder", function()
            vim.api.nvim_buf_set_text(0, 0, 15, 0, 15, { "EDIT" })
            local edited = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            complete()
            assert.same(edited, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("preserves a newline inserted inside the placeholder", function()
            vim.api.nvim_buf_set_text(0, 0, 15, 0, 15, { "", "" })
            local edited = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            complete()
            assert.same(edited, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("preserves a multiline replacement", function()
            vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), { "custom", "text" })
            complete()
            assert.same({ "prefix custom", "textSUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("tracks both endpoints after unrelated preceding edits", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "another line", "BEFORE " })
            complete()
            assert.same(
              { "another line", "BEFORE prefix " .. completion.result .. "SUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("completes after unrelated edits on another line", function()
            vim.api.nvim_buf_set_lines(0, 1, 1, false, { "another line" })
            complete()
            assert.same(
              { "prefix " .. completion.result .. "SUFFIX", "another line" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)
        end)
      end

      for _, reverse_order in ipairs({ false, true }) do
        it(
          "completes independent pastes on one line in " .. (reverse_order and "reverse" or "request") .. " order",
          function()
            local first_callback = fetch_callback
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            smart_paste.smart_paste()
            if reverse_order then
              fetch_callback("<title>Second</title>", nil)
              first_callback("<title>First</title>", nil)
            else
              first_callback("<title>First</title>", nil)
              fetch_callback("<title>Second</title>", nil)
            end
            schedule_spy.flush()
            assert.same(
              { "[Second](" .. url .. ")prefix [First](" .. url .. ")SUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end
        )
      end

      for _, response in ipairs({ "Manual Title", "" }) do
        it("preserves a replacement made while title input is pending: " .. response, function()
          local confirm
          input_spy = mocks.stub_fn(vim.ui, "input", function(_, callback)
            confirm = callback
          end)
          fetch_callback(nil, "timeout")
          schedule_spy.flush()
          assert.is_function(confirm)
          vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), { "custom", "text" })
          confirm(response)
          schedule_spy.flush()
          assert.same({ "prefix custom", "textSUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        end)
      end
    end)
  end)

  describe("_get_clipboard_url", function()
    local orig_getreg

    before_each(function()
      orig_getreg = vim.fn.getreg
    end)

    after_each(function()
      vim.fn.getreg = orig_getreg
    end)

    it("returns URL from + register", function()
      vim.fn.getreg = function(reg)
        if reg == "+" then
          return "https://example.com"
        end
        return ""
      end
      assert.equals("https://example.com", smart_paste._get_clipboard_url())
    end)

    it("returns nil for non-URL content", function()
      vim.fn.getreg = function(reg)
        if reg == "+" then
          return "just some text"
        end
        return ""
      end
      assert.is_nil(smart_paste._get_clipboard_url())
    end)
  end)
end)
