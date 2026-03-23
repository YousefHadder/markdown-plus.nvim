---Test suite for markdown-plus.nvim TOC render module
---Tests formatting and statusline helpers
---@diagnostic disable: undefined-field
local toc_render = require("markdown-plus.headers.toc_render")

describe("markdown-plus toc_render", function()
  describe("format_header_line", function()
    it("indents correctly per level", function()
      local h1_line = toc_render.format_header_line({
        header = { level = 1, text = "Title", line_num = 1 },
        has_children = false,
        is_expanded = false,
      })

      local h3_line = toc_render.format_header_line({
        header = { level = 3, text = "Deep", line_num = 5 },
        has_children = false,
        is_expanded = false,
      })

      -- H1: no indent (0 * 2 spaces)
      assert.is_true(h1_line:match("^  %[H1%]") ~= nil)

      -- H3: 4-space indent (2 * 2 spaces)
      assert.is_true(h3_line:match("^      %[H3%]") ~= nil)
    end)

    it("shows collapsed marker for header with children", function()
      local line = toc_render.format_header_line({
        header = { level = 1, text = "Parent", line_num = 1 },
        has_children = true,
        is_expanded = false,
      })

      assert.is_true(line:match("▶") ~= nil)
      assert.is_nil(line:match("▼"))
    end)

    it("shows expanded marker for expanded header with children", function()
      local line = toc_render.format_header_line({
        header = { level = 1, text = "Parent", line_num = 1 },
        has_children = true,
        is_expanded = true,
      })

      assert.is_true(line:match("▼") ~= nil)
      assert.is_nil(line:match("▶"))
    end)

    it("shows blank space for leaf header (no children)", function()
      local line = toc_render.format_header_line({
        header = { level = 2, text = "Leaf", line_num = 3 },
        has_children = false,
        is_expanded = false,
      })

      -- Should not contain fold markers
      assert.is_nil(line:match("▶"))
      assert.is_nil(line:match("▼"))
    end)

    it("includes level indicator [H1] through [H6]", function()
      for level = 1, 6 do
        local line = toc_render.format_header_line({
          header = { level = level, text = "Header", line_num = level },
          has_children = false,
          is_expanded = false,
        })

        local expected_tag = string.format("[H%d]", level)
        assert.is_true(line:match("%[H" .. level .. "%]") ~= nil, "Missing " .. expected_tag .. " in: " .. line)
      end
    end)

    it("includes header text", function()
      local line = toc_render.format_header_line({
        header = { level = 1, text = "My Title", line_num = 1 },
        has_children = false,
        is_expanded = false,
      })

      assert.is_true(line:match("My Title") ~= nil)
    end)
  end)

  describe("get_toc_statusline", function()
    it("returns a non-empty string", function()
      local statusline = toc_render.get_toc_statusline()
      assert.is_true(#statusline > 0)
    end)

    it("contains key hints", function()
      local statusline = toc_render.get_toc_statusline()
      assert.is_true(statusline:match("expand") ~= nil)
      assert.is_true(statusline:match("collapse") ~= nil)
      assert.is_true(statusline:match("jump") ~= nil)
      assert.is_true(statusline:match("close") ~= nil)
      assert.is_true(statusline:match("help") ~= nil)
    end)
  end)
end)
