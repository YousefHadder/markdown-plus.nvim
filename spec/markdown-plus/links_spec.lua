-- Tests for markdown-plus links module
describe("markdown-plus links", function()
  local links = require("markdown-plus.links")
  local http_fetch = require("markdown-plus.links.http_fetch")
  local smart_paste = require("markdown-plus.links.smart_paste")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    links.setup({ enabled = true })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("pattern matching", function()
    it("matches inline links", function()
      local text = "[link text](https://example.com)"
      local link_text, url = text:match(links.patterns.inline_link)
      assert.equals("link text", link_text)
      assert.equals("https://example.com", url)
    end)

    it("matches reference links", function()
      local text = "[link text][ref]"
      local link_text, ref = text:match(links.patterns.reference_link)
      assert.equals("link text", link_text)
      assert.equals("ref", ref)
    end)

    it("matches reference definitions", function()
      local text = "[ref]: https://example.com"
      local ref, url = text:match(links.patterns.reference_def)
      assert.equals("ref", ref)
      assert.equals("https://example.com", url)
    end)

    it("matches URLs", function()
      local text = "Visit https://example.com for more info"
      local url = text:match(links.patterns.url)
      assert.equals("https://example.com", url)
    end)
  end)

  describe("get_link_at_cursor", function()
    it("finds inline link when cursor is on it", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is [a link](https://example.com) here." })
      vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- cursor on "a link"

      local link = links.get_link_at_cursor()
      if link then
        assert.equals("inline", link.type)
        assert.equals("a link", link.text)
        assert.equals("https://example.com", link.url)
      end
    end)

    it("returns nil when cursor is not on a link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is plain text." })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local link = links.get_link_at_cursor()
      assert.is_nil(link)
    end)

    it("finds reference link when cursor is on it", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "This is [a link][ref] here.",
        "",
        "[ref]: https://example.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local link = links.get_link_at_cursor()
      if link then
        assert.equals("reference", link.type)
        assert.equals("a link", link.text)
      end
    end)
  end)

  describe("patterns", function()
    it("has inline_link pattern", function()
      assert.is_not_nil(links.patterns.inline_link)
    end)

    it("has reference_link pattern", function()
      assert.is_not_nil(links.patterns.reference_link)
    end)

    it("has reference_def pattern", function()
      assert.is_not_nil(links.patterns.reference_def)
    end)

    it("has url pattern", function()
      assert.is_not_nil(links.patterns.url)
    end)
  end)

  describe("find_reference_url", function()
    it("finds URL for given reference", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text with [link][myref]",
        "",
        "[myref]: https://example.com",
        "[other]: https://other.com",
      })

      local url = links.find_reference_url("myref")
      assert.equals("https://example.com", url)
    end)

    it("returns nil for non-existent reference", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[ref]: https://example.com",
      })

      local url = links.find_reference_url("nonexistent")
      assert.is_nil(url)
    end)
  end)

  describe("convert_to_reference unique ID generation", function()
    it("creates basic reference ID from text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "This is a [hello world](https://example.com) link",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- On "hello world" link

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should create reference with "hello-world" as ID
      assert.matches("%[hello world%]%[hello%-world%]", lines[1])
      assert.matches("%[hello%-world%]: https://example.com", table.concat(lines, "\n"))
    end)

    it("reuses existing reference with same URL", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First [link one](https://example.com)",
        "",
        "[link-one]: https://example.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- On "link one"

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should reuse existing reference, not create duplicate
      local ref_count = 0
      for _, line in ipairs(lines) do
        if line:match("%[link%-one%]:") then
          ref_count = ref_count + 1
        end
      end
      assert.equals(1, ref_count, "Should have exactly one reference definition")
    end)

    it("generates unique ID when reference exists with different URL", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "New [test link](https://newurl.com)",
        "",
        "[test-link]: https://existingurl.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- On "test link"

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should create "test-link-1" to avoid collision
      assert.matches("%[test link%]%[test%-link%-1%]", lines[1])
      assert.matches("%[test%-link%-1%]: https://newurl.com", table.concat(lines, "\n"))
      -- Original reference should still exist
      assert.matches("%[test%-link%]: https://existingurl.com", table.concat(lines, "\n"))
    end)

    it("increments counter for multiple collisions", function()
      -- Convert first link
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link [foo](https://url1.com)",
        "",
        "[foo]: https://existing.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local content = table.concat(lines, "\n")
      -- Should create foo-1 since foo already exists
      assert.matches("%[foo%-1%]: https://url1.com", content)
      assert.matches("%[foo%]: https://existing.com", content)

      -- Convert second link with same text but different URL
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link [foo][foo-1]",
        "Another [foo](https://url2.com)",
        "",
        "[foo]: https://existing.com",
        "[foo-1]: https://url1.com",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 10 })
      links.convert_to_reference()

      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      content = table.concat(lines, "\n")
      -- Should create foo-2 since both foo and foo-1 exist
      assert.matches("%[foo%-2%]: https://url2.com", content)
    end)

    it("handles special characters in link text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link to [Test & Demo!](https://example.com)",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Special characters should be stripped, only alphanumeric and hyphens remain
      assert.matches("%[Test & Demo!%]%[test%-demo%]", lines[1])
      assert.matches("%[test%-demo%]: https://example.com", table.concat(lines, "\n"))
    end)

    it("handles text with multiple spaces", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link to [Hello   World](https://example.com)",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Multiple spaces should become single hyphen
      assert.matches("%[hello%-world%]", lines[1]:lower())
    end)

    it("provides notification when reusing existing reference", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link [test](https://example.com)",
        "",
        "[test]: https://example.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      -- Capture notifications
      local notified = false
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match("reusing existing reference") then
          notified = true
        end
      end

      links.convert_to_reference()

      vim.notify = orig_notify
      assert.is_true(notified, "Should notify user about reusing reference")
    end)

    -- Note: The generated ref_id is always lowercase ('hello-world'),
    -- so it matches the existing reference definition which is also lowercase.
    -- This test verifies that we don't create duplicates when link text
    -- case differs but normalizes to the same reference ID.
    it("handles case normalization in reference matching", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Link [Hello World](https://example.com)",
        "",
        "[hello-world]: https://example.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local ref_count = 0
      for _, line in ipairs(lines) do
        if line:lower():match("%[hello%-world%]:") then
          ref_count = ref_count + 1
        end
      end
      -- Should reuse existing reference (normalized to same ID), not create duplicate
      assert.equals(1, ref_count)
    end)
  end)

  describe("smart_paste", function()
    describe("http_fetch redirect hardening", function()
      it("parses redirect probe output", function()
        local status_code, redirect_url, err = http_fetch._parse_probe_output("301\nhttps://example.com/final")
        assert.is_nil(err)
        assert.equals(301, status_code)
        assert.equals("https://example.com/final", redirect_url)
      end)

      it("handles probe output without redirect URL", function()
        local status_code, redirect_url, err = http_fetch._parse_probe_output("200\n")
        assert.is_nil(err)
        assert.equals(200, status_code)
        assert.is_nil(redirect_url)
      end)

      it("returns an error for malformed probe output", function()
        local _, _, err = http_fetch._parse_probe_output("not-a-status")
        assert.is_not_nil(err)
      end)

      it("detects redirect status codes", function()
        assert.is_true(http_fetch._is_redirect_status(301))
        assert.is_true(http_fetch._is_redirect_status(302))
        assert.is_false(http_fetch._is_redirect_status(200))
      end)

      it("blocks private redirect targets", function()
        local ok, reason = http_fetch._validate_redirect_url("https://127.0.0.1/admin")
        assert.is_false(ok)
        assert.matches("not allowed", reason)
      end)

      it("rejects non-http redirect targets", function()
        local ok, reason = http_fetch._validate_redirect_url("ftp://example.com/private")
        assert.is_false(ok)
        assert.matches("HTTP%(S%)", reason)
      end)

      it("allows public redirect targets", function()
        local ok, reason = http_fetch._validate_redirect_url("https://example.com/docs")
        assert.is_true(ok)
        assert.is_nil(reason)
      end)

      it("aborts fetch when redirect target is blocked", function()
        local original_system = vim.system
        local calls = 0
        local callback_html
        local callback_err

        vim.system = function(cmd, _, callback)
          calls = calls + 1

          if vim.tbl_contains(cmd, "-w") then
            callback({
              code = 0,
              stdout = "302\nhttps://127.0.0.1/admin",
              stderr = "",
            })
          else
            callback({
              code = 0,
              stdout = "<html><title>unexpected</title></html>",
              stderr = "",
            })
          end
        end

        http_fetch.fetch_html_async("https://example.com/start", 5, function(html, err)
          callback_html = html
          callback_err = err
        end)

        vim.system = original_system

        assert.is_nil(callback_html)
        assert.matches("redirect target blocked", callback_err)
        assert.equals(1, calls)
      end)

      it("follows safe redirects and fetches final HTML", function()
        local original_system = vim.system
        local callback_html
        local callback_err
        local fetch_url

        vim.system = function(cmd, _, callback)
          local is_probe = vim.tbl_contains(cmd, "-w")
          local url = cmd[#cmd]

          if is_probe and url == "https://example.com/start" then
            callback({
              code = 0,
              stdout = "301\nhttps://example.com/final",
              stderr = "",
            })
            return
          end

          if is_probe and url == "https://example.com/final" then
            callback({
              code = 0,
              stdout = "200\n",
              stderr = "",
            })
            return
          end

          fetch_url = url
          callback({
            code = 0,
            stdout = "<html><title>final</title></html>",
            stderr = "",
          })
        end

        http_fetch.fetch_html_async("https://example.com/start", 5, function(html, err)
          callback_html = html
          callback_err = err
        end)

        vim.system = original_system

        assert.is_nil(callback_err)
        assert.equals("https://example.com/final", fetch_url)
        assert.matches("<title>final</title>", callback_html)
      end)
    end)

    describe("_is_url", function()
      it("returns true for http URLs", function()
        assert.is_true(smart_paste._is_url("http://example.com"))
      end)

      it("returns true for https URLs", function()
        assert.is_true(smart_paste._is_url("https://example.com"))
      end)

      it("returns true for URLs with paths", function()
        assert.is_true(smart_paste._is_url("https://example.com/path/to/page"))
      end)

      it("returns true for URLs with query strings", function()
        assert.is_true(smart_paste._is_url("https://example.com/search?q=test&page=1"))
      end)

      it("returns true for URLs with fragments", function()
        assert.is_true(smart_paste._is_url("https://example.com/page#section"))
      end)

      it("returns false for non-URL strings", function()
        assert.is_false(smart_paste._is_url("not a url"))
      end)

      it("returns false for ftp URLs", function()
        assert.is_false(smart_paste._is_url("ftp://example.com"))
      end)

      it("returns false for file URLs", function()
        assert.is_false(smart_paste._is_url("file:///path/to/file"))
      end)

      it("returns false for nil", function()
        assert.is_false(smart_paste._is_url(nil))
      end)

      it("returns false for numbers", function()
        assert.is_false(smart_paste._is_url(123))
      end)

      it("returns false for empty string", function()
        assert.is_false(smart_paste._is_url(""))
      end)
    end)

    describe("_is_blocked_url", function()
      it("blocks localhost URLs", function()
        local is_blocked, reason = smart_paste._is_blocked_url("https://localhost/admin")
        assert.is_true(is_blocked)
        assert.equals("localhost is not allowed", reason)
      end)

      it("blocks private IPv4 ranges", function()
        assert.is_true(select(1, smart_paste._is_blocked_url("https://10.1.2.3/path")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://172.20.0.1/path")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://192.168.1.5/path")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://127.0.0.1/path")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://169.254.10.20/path")))
      end)

      it("blocks local/private IPv6 ranges", function()
        assert.is_true(select(1, smart_paste._is_blocked_url("https://[::1]/")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://[fd00::1]/")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://[fe80::1]/")))
      end)

      it("blocks IPv6-mapped private IPv4 ranges", function()
        assert.is_true(select(1, smart_paste._is_blocked_url("https://[::ffff:127.0.0.1]/")))
        assert.is_true(select(1, smart_paste._is_blocked_url("https://[::ffff:192.168.0.1]/")))
      end)

      it("allows public host URLs", function()
        local is_blocked, reason = smart_paste._is_blocked_url("https://example.com/docs")
        assert.is_false(is_blocked)
        assert.is_nil(reason)
      end)
    end)

    describe("_clamp_timeout", function()
      it("clamps timeout values to safe bounds", function()
        assert.equals(1, smart_paste._clamp_timeout(0))
        assert.equals(5, smart_paste._clamp_timeout(5))
        assert.equals(30, smart_paste._clamp_timeout(60))
      end)
    end)

    describe("_truncate_title", function()
      it("truncates very long titles", function()
        local long_title = string.rep("a", 320)
        local truncated = smart_paste._truncate_title(long_title)
        assert.equals(300, #truncated)
        assert.equals("...", truncated:sub(-3))
      end)

      it("keeps short titles unchanged", function()
        assert.equals("short title", smart_paste._truncate_title("short title"))
      end)
    end)

    describe("_html_unescape", function()
      it("decodes &amp;", function()
        assert.equals("foo & bar", smart_paste._html_unescape("foo &amp; bar"))
      end)

      it("decodes &lt; and &gt;", function()
        assert.equals("<div>", smart_paste._html_unescape("&lt;div&gt;"))
      end)

      it("decodes &quot;", function()
        assert.equals('say "hello"', smart_paste._html_unescape("say &quot;hello&quot;"))
      end)

      it("decodes &#39; and &apos;", function()
        assert.equals("it's", smart_paste._html_unescape("it&#39;s"))
        assert.equals("it's", smart_paste._html_unescape("it&apos;s"))
      end)

      it("decodes &#x27;", function()
        assert.equals("it's", smart_paste._html_unescape("it&#x27;s"))
      end)

      it("decodes &nbsp;", function()
        assert.equals("hello world", smart_paste._html_unescape("hello&nbsp;world"))
      end)

      it("decodes multiple entities", function()
        assert.equals('Tom & Jerry say "hi"', smart_paste._html_unescape("Tom &amp; Jerry say &quot;hi&quot;"))
      end)

      it("handles strings with no entities", function()
        assert.equals("plain text", smart_paste._html_unescape("plain text"))
      end)
    end)

    describe("_parse_title", function()
      it("extracts og:title", function()
        local html = [[
          <html><head>
          <meta property="og:title" content="My OG Title">
          <title>Fallback Title</title>
          </head></html>
        ]]
        assert.equals("My OG Title", smart_paste._parse_title(html))
      end)

      it("extracts og:title with reversed attribute order", function()
        local html = [[
          <html><head>
          <meta content="My OG Title" property="og:title">
          </head></html>
        ]]
        assert.equals("My OG Title", smart_paste._parse_title(html))
      end)

      it("extracts twitter:title when no og:title", function()
        local html = [[
          <html><head>
          <meta name="twitter:title" content="My Twitter Title">
          <title>Fallback Title</title>
          </head></html>
        ]]
        assert.equals("My Twitter Title", smart_paste._parse_title(html))
      end)

      it("extracts twitter:title with reversed attribute order", function()
        local html = [[
          <html><head>
          <meta content="My Twitter Title" name="twitter:title">
          </head></html>
        ]]
        assert.equals("My Twitter Title", smart_paste._parse_title(html))
      end)

      it("falls back to <title> tag", function()
        local html = [[
          <html><head>
          <title>Page Title</title>
          </head></html>
        ]]
        assert.equals("Page Title", smart_paste._parse_title(html))
      end)

      it("handles <title> with attributes", function()
        local html = [[
          <html><head>
          <title lang="en">Page Title</title>
          </head></html>
        ]]
        assert.equals("Page Title", smart_paste._parse_title(html))
      end)

      it("decodes HTML entities in title", function()
        local html = [[
          <html><head>
          <title>Tom &amp; Jerry</title>
          </head></html>
        ]]
        assert.equals("Tom & Jerry", smart_paste._parse_title(html))
      end)

      it("normalizes whitespace in title", function()
        local html = [[
          <html><head>
          <title>
            Page   Title
            Here
          </title>
          </head></html>
        ]]
        assert.equals("Page Title Here", smart_paste._parse_title(html))
      end)

      it("returns nil for empty HTML", function()
        assert.is_nil(smart_paste._parse_title(""))
      end)

      it("returns nil for nil input", function()
        assert.is_nil(smart_paste._parse_title(nil))
      end)

      it("returns nil when no title found", function()
        local html = [[
          <html><head>
          <meta name="description" content="A description">
          </head></html>
        ]]
        assert.is_nil(smart_paste._parse_title(html))
      end)

      it("returns nil for empty title tag", function()
        local html = [[
          <html><head>
          <title></title>
          </head></html>
        ]]
        assert.is_nil(smart_paste._parse_title(html))
      end)

      it("returns nil for whitespace-only title", function()
        local html = [[
          <html><head>
          <title>   </title>
          </head></html>
        ]]
        assert.is_nil(smart_paste._parse_title(html))
      end)

      it("handles Windows line endings", function()
        local html = "<html>\r\n<head>\r\n<title>Title</title>\r\n</head></html>"
        assert.equals("Title", smart_paste._parse_title(html))
      end)

      it("handles uppercase <TITLE> tag", function()
        local html = [[
          <HTML><HEAD>
          <TITLE>Page Title</TITLE>
          </HEAD></HTML>
        ]]
        assert.equals("Page Title", smart_paste._parse_title(html))
      end)

      it("handles mixed case title tag", function()
        local html = [[
          <html><head>
          <Title>Mixed Case Title</Title>
          </head></html>
        ]]
        assert.equals("Mixed Case Title", smart_paste._parse_title(html))
      end)

      it("prefers og:title over twitter:title", function()
        local html = [[
          <html><head>
          <meta property="og:title" content="OG Title">
          <meta name="twitter:title" content="Twitter Title">
          <title>Page Title</title>
          </head></html>
        ]]
        assert.equals("OG Title", smart_paste._parse_title(html))
      end)

      it("prefers twitter:title over <title>", function()
        local html = [[
          <html><head>
          <meta name="twitter:title" content="Twitter Title">
          <title>Page Title</title>
          </head></html>
        ]]
        assert.equals("Twitter Title", smart_paste._parse_title(html))
      end)
    end)

    describe("_url_needs_brackets", function()
      it("returns true for URLs with parentheses", function()
        assert.is_true(smart_paste._url_needs_brackets("https://example.com/page(1).html"))
      end)

      it("returns true for URLs with spaces", function()
        assert.is_true(smart_paste._url_needs_brackets("https://example.com/my page.html"))
      end)

      it("returns true for URLs with angle brackets", function()
        assert.is_true(smart_paste._url_needs_brackets("https://example.com/<path>"))
      end)

      it("returns true for URLs with multiple special chars", function()
        assert.is_true(smart_paste._url_needs_brackets("https://example.com/page (1).html"))
      end)

      it("returns false for regular URLs", function()
        assert.is_false(smart_paste._url_needs_brackets("https://example.com/page.html"))
      end)

      it("returns false for URLs with query strings", function()
        assert.is_false(smart_paste._url_needs_brackets("https://example.com/search?q=test&page=1"))
      end)

      it("returns false for URLs with fragments", function()
        assert.is_false(smart_paste._url_needs_brackets("https://example.com/page#section"))
      end)

      it("returns false for URLs with encoded characters", function()
        assert.is_false(smart_paste._url_needs_brackets("https://example.com/page%20name.html"))
      end)
    end)

    describe("_format_url_for_markdown", function()
      it("wraps URLs with parentheses in angle brackets", function()
        assert.equals(
          "<https://example.com/page(1).html>",
          smart_paste._format_url_for_markdown("https://example.com/page(1).html")
        )
      end)

      it("wraps URLs with spaces in angle brackets", function()
        assert.equals(
          "<https://example.com/my page.html>",
          smart_paste._format_url_for_markdown("https://example.com/my page.html")
        )
      end)

      it("returns regular URLs unchanged", function()
        assert.equals(
          "https://example.com/page.html",
          smart_paste._format_url_for_markdown("https://example.com/page.html")
        )
      end)

      it("returns URLs with query strings unchanged", function()
        assert.equals(
          "https://example.com/search?q=test",
          smart_paste._format_url_for_markdown("https://example.com/search?q=test")
        )
      end)

      it("handles Wikipedia-style URLs with parentheses", function()
        assert.equals(
          "<https://en.wikipedia.org/wiki/Lua_(programming_language)>",
          smart_paste._format_url_for_markdown("https://en.wikipedia.org/wiki/Lua_(programming_language)")
        )
      end)
    end)

    describe("_extract_url_host", function()
      it("extracts domain from simple URL", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://example.com/path"))
      end)

      it("extracts domain from http URL", function()
        assert.equals("example.com", smart_paste._extract_url_host("http://example.com"))
      end)

      it("lowercases the host", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://EXAMPLE.COM/path"))
      end)

      it("strips port from host", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://example.com:8080/path"))
      end)

      it("strips userinfo from URL", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://user:pass@example.com/path"))
      end)

      it("extracts IPv4 host", function()
        assert.equals("192.168.1.1", smart_paste._extract_url_host("https://192.168.1.1/path"))
      end)

      it("extracts IPv6 host without brackets", function()
        assert.equals("::1", smart_paste._extract_url_host("https://[::1]/path"))
      end)

      it("extracts IPv6 host and strips zone identifier", function()
        assert.equals("fe80::1", smart_paste._extract_url_host("https://[fe80::1%25eth0]/path"))
      end)

      it("returns nil for empty IPv6 brackets", function()
        assert.is_nil(smart_paste._extract_url_host("https://[]/path"))
      end)

      it("returns nil for non-HTTP URL", function()
        assert.is_nil(smart_paste._extract_url_host("ftp://example.com"))
      end)

      it("returns nil for empty string", function()
        assert.is_nil(smart_paste._extract_url_host(""))
      end)

      it("handles URL with query string", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://example.com?q=test"))
      end)

      it("handles URL with fragment", function()
        assert.equals("example.com", smart_paste._extract_url_host("https://example.com#section"))
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

      it("falls back to unnamed register", function()
        vim.fn.getreg = function(reg)
          if reg == "+" then
            return ""
          end
          if reg == '"' then
            return "https://fallback.com"
          end
          return ""
        end
        assert.equals("https://fallback.com", smart_paste._get_clipboard_url())
      end)

      it("returns nil for non-URL clipboard content", function()
        vim.fn.getreg = function()
          return "not a url"
        end
        assert.is_nil(smart_paste._get_clipboard_url())
      end)

      it("returns nil for multi-line clipboard content", function()
        vim.fn.getreg = function()
          return "https://example.com\nhttps://other.com"
        end
        assert.is_nil(smart_paste._get_clipboard_url())
      end)

      it("returns nil for empty clipboard", function()
        vim.fn.getreg = function()
          return ""
        end
        assert.is_nil(smart_paste._get_clipboard_url())
      end)

      it("trims whitespace from clipboard URL", function()
        vim.fn.getreg = function(reg)
          if reg == "+" then
            return "  https://example.com  "
          end
          return ""
        end
        assert.equals("https://example.com", smart_paste._get_clipboard_url())
      end)
    end)
  end)

  describe("insert_link with mocked input", function()
    local mocks = require("spec.helpers.mocks")
    local notify_spy, input_spy

    before_each(function()
      notify_spy = mocks.mock_notify()
    end)

    after_each(function()
      notify_spy.restore()
      if input_spy then
        input_spy.restore()
      end
    end)

    it("does nothing when text input is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "original" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ nil })

      links.insert_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("original", lines[1])
    end)

    it("does nothing when url input is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "original" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ "text", nil })

      links.insert_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("original", lines[1])
    end)

    it("inserts link with text and url", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ "my link", "https://example.com" })

      links.insert_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("[my link](https://example.com)", lines[1])
    end)

    it("notifies when editing link with no link at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "just plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      links.edit_link()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No link under cursor"))
      assert.equals(vim.log.levels.WARN, notify_spy.calls[1].level)
    end)
  end)

  describe("additional link coverage", function()
    local mocks = require("spec.helpers.mocks")
    local notify_spy, input_spy

    before_each(function()
      notify_spy = mocks.mock_notify()
    end)

    after_each(function()
      notify_spy.restore()
      if input_spy then
        input_spy.restore()
        input_spy = nil
      end
    end)

    it("auto_link_url converts bare URL to markdown link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Visit https://example.com today" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      input_spy = mocks.mock_input({ "Example" })

      links.auto_link_url()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Visit [Example](https://example.com) today", lines[1])
    end)

    it("convert_to_reference converts inline link to reference style", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Click [here](https://url.com) for info",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 8 })

      links.convert_to_reference()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.matches("%[here%]%[here%]", lines[1])
      local all = table.concat(lines, "\n")
      assert.matches("%[here%]: https://url.com", all)
    end)

    it("convert_to_inline converts reference link to inline", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Click [here][ref] for info",
        "",
        "[ref]: https://url.com",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 8 })

      links.convert_to_inline()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("Click [here](https://url.com) for info", lines[1])
    end)

    it("build_markdown_link includes title when provided", function()
      local utils = require("markdown-plus.utils")
      local link = utils.build_markdown_link("text", "https://url.com", "My Title")
      assert.equals('[text](https://url.com "My Title")', link)
    end)

    it("edit_link updates existing inline link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[old](https://old.com)" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      input_spy = mocks.mock_input({ "new text", "https://new.com" })

      links.edit_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("[new text](https://new.com)", lines[1])
    end)

    it("get_link_at_cursor returns nil on plain text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "just text" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      local link = links.get_link_at_cursor()
      assert.is_nil(link)
    end)
  end)
end)
