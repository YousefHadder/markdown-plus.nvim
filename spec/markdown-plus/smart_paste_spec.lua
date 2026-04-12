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
end)
