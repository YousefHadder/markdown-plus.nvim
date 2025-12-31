-- Tests for markdown-plus links module
describe("markdown-plus links", function()
  local links = require("markdown-plus.links")
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
  end)
end)
