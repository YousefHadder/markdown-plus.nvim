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
    local notify_spy, schedule_spy, input_spy, select_spy, checkbox_config_spy
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
      if select_spy then
        select_spy.restore()
        select_spy = nil
      end
      if checkbox_config_spy then
        checkbox_config_spy.restore()
        checkbox_config_spy = nil
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
      local renumber_buf
      local timestamp = " <!-- completed: 2000-01-02 -->"

      ---Read the byte column immediately after the pending placeholder.
      ---@return integer
      local function placeholder_end()
        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        return assert(line:find("SUFFIX", 1, true)) - 1
      end

      ---Use a deterministic completion timestamp through the production checkbox writer.
      ---@return nil
      local function enable_checkbox_timestamps()
        checkbox_config_spy = mocks.stub_fn(require("markdown-plus.list.checkbox"), "get_completion_config", function()
          return {
            enabled = true,
            format = "comment",
            date_format = "2000-01-02",
            remove_on_uncheck = true,
            update_existing = true,
          }
        end)
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

      after_each(function()
        if renumber_buf then
          require("markdown-plus.list.autocmds").stop_debounce_timer(renumber_buf)
          pcall(vim.api.nvim_del_augroup_by_name, "MarkdownPlusListRenumber_" .. renumber_buf)
          renumber_buf = nil
        end
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

          it("completes after renumbering adjacent list items", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "9. " })
            vim.api.nvim_buf_set_lines(0, 1, 1, false, { "9. next" })
            require("markdown-plus.list.renumber").renumber_ordered_lists()
            complete()
            assert.same(
              { "1. prefix " .. completion.result .. "SUFFIX", "2. next" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("completes after automatic TextChanged renumbering", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "9. " })
            renumber_buf = vim.api.nvim_get_current_buf()
            require("markdown-plus.list.autocmds").setup_renumber_autocmds()
            vim.api.nvim_exec_autocmds("TextChanged", { buffer = renumber_buf })
            assert.matches("^1%. prefix ", vim.api.nvim_get_current_line())
            complete()
            assert.same({ "1. prefix " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after a helper edits only the line prefix", function()
            require("markdown-plus.utils").set_line(1, "BEFORE " .. vim.api.nvim_get_current_line())
            complete()
            assert.same(
              { "BEFORE prefix " .. completion.result .. "SUFFIX" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("completes after a helper edits only the line suffix", function()
            require("markdown-plus.utils").set_line(1, vim.api.nvim_get_current_line() .. " AFTER")
            complete()
            assert.same(
              { "prefix " .. completion.result .. "SUFFIX AFTER" },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("completes after a helper leaves the line unchanged", function()
            require("markdown-plus.utils").set_line(1, vim.api.nvim_get_current_line())
            complete()
            assert.same({ "prefix " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          for _, boundary in ipairs({ "before", "after" }) do
            it("completes after inserting an existing footnote " .. boundary .. " the placeholder", function()
              vim.api.nvim_buf_set_lines(0, 1, 1, false, { "", "[^note]: existing" })
              vim.api.nvim_win_set_cursor(0, { 1, boundary == "before" and 6 or placeholder_end() - 1 })
              input_spy = mocks.mock_input({ "note" })
              require("markdown-plus.footnotes.insertion").insert_footnote()
              input_spy.restore()
              input_spy = nil
              complete()
              assert.same({
                "prefix "
                  .. (boundary == "before" and "[^note]" or "")
                  .. completion.result
                  .. (boundary == "after" and "[^note]" or "")
                  .. "SUFFIX",
                "",
                "[^note]: existing",
              }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
            end)

            it("completes after inserting a table break " .. boundary .. " the placeholder", function()
              vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "| " })
              local line_end = #vim.api.nvim_get_current_line()
              vim.api.nvim_buf_set_text(0, 0, line_end, 0, line_end, { " |" })
              vim.api.nvim_buf_set_lines(0, 1, 1, false, { "| --- |" })
              vim.api.nvim_win_set_cursor(0, { 1, boundary == "before" and 9 or placeholder_end() })
              assert.is_true(require("markdown-plus.table.cell_ops").insert_break())
              complete()
              assert.same({
                "| prefix "
                  .. (boundary == "before" and "<br>" or "")
                  .. completion.result
                  .. (boundary == "after" and "<br>" or "")
                  .. "SUFFIX |",
                "| --- |",
              }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
            end)
          end

          it("completes after inserting a new footnote and its definition", function()
            vim.api.nvim_win_set_cursor(0, { 1, 6 })
            input_spy = mocks.mock_input({ "note" })
            require("markdown-plus.footnotes.insertion").insert_footnote()
            input_spy.restore()
            input_spy = nil
            vim.cmd("stopinsert")
            complete()
            assert.same({
              "prefix [^note]" .. completion.result .. "SUFFIX",
              "",
              "## Footnotes",
              "",
              "[^note]: ",
            }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after adding a checkbox immediately before the placeholder", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- " })
            require("markdown-plus.list.checkbox").toggle_checkbox_on_line(1)
            complete()
            assert.same({ "- [ ] " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          for _, with_timestamp in ipairs({ false, true }) do
            it("completes after checking an empty checkbox state, timestamps=" .. tostring(with_timestamp), function()
              vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- [] " })
              if with_timestamp then
                enable_checkbox_timestamps()
              end
              require("markdown-plus.list.checkbox").toggle_checkbox_on_line(1)
              complete()
              assert.same(
                { "- [x] " .. completion.result .. "SUFFIX" .. (with_timestamp and timestamp or "") },
                vim.api.nvim_buf_get_lines(0, 0, -1, false)
              )
            end)
          end

          it("completes after checking a task and adding a timestamp", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- [ ] " })
            enable_checkbox_timestamps()
            require("markdown-plus.list.checkbox").toggle_checkbox_on_line(1)
            complete()
            assert.same(
              { "- [x] " .. completion.result .. "SUFFIX" .. timestamp },
              vim.api.nvim_buf_get_lines(0, 0, -1, false)
            )
          end)

          it("completes after unchecking a task and removing its timestamp", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- [x] " })
            local line_end = #vim.api.nvim_get_current_line()
            vim.api.nvim_buf_set_text(0, 0, line_end, 0, line_end, { timestamp })
            enable_checkbox_timestamps()
            require("markdown-plus.list.checkbox").toggle_checkbox_on_line(1)
            complete()
            assert.same({ "- [ ] " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after changing the list type to task", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- " })
            require("markdown-plus.list.toggle").toggle_list_line("task")
            complete()
            assert.same({ "- [ ] " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after toggling off the task list marker", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- [ ] " })
            require("markdown-plus.list.toggle").toggle_list_line("task")
            complete()
            assert.same({ completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after clearing the list marker", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- " })
            require("markdown-plus.list.toggle").clear_list_line()
            complete()
            assert.same({ completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after converting a blockquote to a callout", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "> " })
            select_spy = mocks.mock_select(1)
            require("markdown-plus.callouts").convert_to_callout()
            complete()
            assert.same({ "> [!NOTE] " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after converting a callout to a blockquote", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "> [!NOTE] " })
            require("markdown-plus.callouts").convert_to_blockquote()
            complete()
            assert.same({ "> " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          it("completes after a callout conversion round trip", function()
            vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "> " })
            select_spy = mocks.mock_select(1)
            local callouts = require("markdown-plus.callouts")
            callouts.convert_to_callout()
            callouts.convert_to_blockquote()
            complete()
            assert.same({ "> " .. completion.result .. "SUFFIX" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
          end)

          for _, split in ipairs({
            { name = "Enter", run = require("markdown-plus.list.enter_handler").handle_enter, prefix = "- " },
            {
              name = "continuation Enter",
              run = require("markdown-plus.list.enter_handler").continue_list_content,
              prefix = "  ",
            },
          }) do
            it("completes after " .. split.name .. " at the starting boundary", function()
              vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- text " })
              vim.api.nvim_win_set_cursor(0, { 1, 7 })
              split.run()
              complete()
              assert.same(
                { "- text ", split.prefix .. completion.result .. "SUFFIX" },
                vim.api.nvim_buf_get_lines(0, 0, -1, false)
              )
            end)

            it("completes after " .. split.name .. " at the ending boundary", function()
              vim.api.nvim_buf_set_text(0, 0, 0, 0, 7, { "- text " })
              vim.api.nvim_win_set_cursor(0, { 1, placeholder_end() })
              split.run()
              complete()
              assert.same(
                { "- text " .. completion.result, split.prefix .. "SUFFIX" },
                vim.api.nvim_buf_get_lines(0, 0, -1, false)
              )
            end)
          end
        end)
      end

      for _, failure in ipairs({
        { name = "fetch failure", err = "timeout" },
        { name = "missing page title", html = "<html><body>No title</body></html>" },
      }) do
        for _, abandoned in ipairs({
          {
            name = "deleted placeholder",
            edit = function()
              vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), {})
            end,
          },
          {
            name = "replaced placeholder",
            edit = function()
              vim.api.nvim_buf_set_text(0, 0, 7, 0, placeholder_end(), { "custom text" })
            end,
          },
          {
            name = "multiline placeholder",
            edit = function()
              vim.api.nvim_buf_set_text(0, 0, 15, 0, 15, { "", "" })
            end,
          },
          {
            name = "wiped source buffer",
            edit = function()
              vim.api.nvim_buf_delete(0, { force = true })
            end,
          },
          {
            name = "missing tracking mark",
            edit = function()
              local ns = vim.api.nvim_create_namespace("markdown_plus_smart_paste")
              vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
            end,
          },
          {
            name = "non-modifiable source buffer",
            edit = function()
              vim.bo.modifiable = false
            end,
          },
        }) do
          it("does not prompt after " .. failure.name .. " for a " .. abandoned.name, function()
            abandoned.edit()
            input_spy = mocks.mock_input({ "Unused title" })
            fetch_callback(failure.html, failure.err)
            schedule_spy.flush()
            schedule_spy.flush()
            vim.bo.modifiable = true
            assert.equals(0, #input_spy.calls)
            for _, call in ipairs(notify_spy.calls) do
              assert.is_nil(call.msg:find("Failed to fetch", 1, true))
              assert.is_nil(call.msg:find("Could not extract title", 1, true))
            end
          end)
        end
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
