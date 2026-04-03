-- Tests for markdown-plus footnotes query sub-module
describe("markdown-plus footnotes query", function()
  local query = require("markdown-plus.footnotes.query")
  local parser = require("markdown-plus.footnotes.parser")
  local footnotes = require("markdown-plus.footnotes")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    footnotes.setup({
      footnotes = {
        section_header = "Footnotes",
        confirm_delete = false,
      },
    })
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("get_all_footnotes", function()
    it("combines references and definitions", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^1] here.",
        "",
        "[^1]: Definition.",
      })

      local all = query.get_all_footnotes(0)
      assert.equals(1, #all)
      assert.equals("1", all[1].id)
      assert.is_not_nil(all[1].definition)
      assert.equals(1, #all[1].references)
    end)

    it("detects orphan references", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^1] with no definition.",
      })

      local all = query.get_all_footnotes(0)
      assert.equals(1, #all)
      assert.is_nil(all[1].definition)
    end)

    it("detects orphan definitions", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "No references here.",
        "[^1]: Orphan definition.",
      })

      local all = query.get_all_footnotes(0)
      assert.equals(1, #all)
      assert.equals(0, #all[1].references)
    end)

    it("sorts by first appearance", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^2] first.",
        "Text[^1] second.",
      })

      local all = query.get_all_footnotes(0)
      assert.equals("2", all[1].id)
      assert.equals("1", all[2].id)
    end)

    it("works through parser facade", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^1].",
        "[^1]: Def.",
      })

      local direct = query.get_all_footnotes(0)
      local facade = parser.get_all_footnotes(0)
      assert.equals(#direct, #facade)
    end)
  end)

  describe("get_next_numeric_id", function()
    it("returns 1 when no footnotes", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Empty." })

      assert.equals("1", query.get_next_numeric_id(0))
    end)

    it("returns next after highest", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^3].",
        "[^3]: Def.",
      })

      assert.equals("4", query.get_next_numeric_id(0))
    end)

    it("ignores non-numeric IDs", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^note].",
        "[^note]: Def.",
      })

      assert.equals("1", query.get_next_numeric_id(0))
    end)
  end)

  describe("find_footnotes_section", function()
    it("finds section header", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Content.",
        "",
        "## Footnotes",
        "[^1]: Def.",
      })

      assert.equals(3, query.find_footnotes_section(0, "Footnotes"))
    end)

    it("returns nil when not found", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "No section." })

      assert.is_nil(query.find_footnotes_section(0))
    end)

    it("supports custom header text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "## Notes",
      })

      assert.equals(1, query.find_footnotes_section(0, "Notes"))
    end)
  end)

  describe("get_definition_range", function()
    it("returns range for single-line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: Single." })

      local s, e = query.get_definition_range(0, 1)
      assert.equals(1, s)
      assert.equals(1, e)
    end)

    it("returns range for multi-line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^1]: First",
        "    Second",
        "    Third",
      })

      local s, e = query.get_definition_range(0, 1)
      assert.equals(1, s)
      assert.equals(3, e)
    end)

    it("returns nil for non-definition line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a def." })

      local s, e = query.get_definition_range(0, 1)
      assert.is_nil(s)
      assert.is_nil(e)
    end)

    it("returns nil for out-of-range line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "One line." })

      local s, e = query.get_definition_range(0, 99)
      assert.is_nil(s)
      assert.is_nil(e)
    end)
  end)

  describe("get_definition_content", function()
    it("returns single-line content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: Hello world." })

      local content = query.get_definition_content(0, 1)
      assert.equals("Hello world.", content)
    end)

    it("returns multi-line content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^1]: Line one",
        "    Line two",
      })

      local content = query.get_definition_content(0, 1)
      assert.is_not_nil(content)
      assert.truthy(content:find("Line one"))
      assert.truthy(content:find("Line two"))
    end)

    it("returns nil for non-definition", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Not a def." })

      assert.is_nil(query.get_definition_content(0, 1))
    end)
  end)

  describe("get_footnote_at_cursor", function()
    it("detects reference at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Text[^1] here." })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local result = query.get_footnote_at_cursor(0, 1, 6)
      assert.is_not_nil(result)
      assert.equals("reference", result.type)
      assert.equals("1", result.id)
    end)

    it("detects definition at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: Definition." })

      local result = query.get_footnote_at_cursor(0, 1, 1)
      assert.is_not_nil(result)
      assert.equals("definition", result.type)
      assert.equals("1", result.id)
    end)

    it("returns nil when not on footnote", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Plain text." })

      local result = query.get_footnote_at_cursor(0, 1, 1)
      assert.is_nil(result)
    end)

    it("returns nil inside code block", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "```",
        "Text[^1] in code.",
        "```",
      })

      local result = query.get_footnote_at_cursor(0, 2, 6)
      assert.is_nil(result)
    end)

    it("works through parser facade", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: Def." })

      local direct = query.get_footnote_at_cursor(0, 1, 1)
      local facade = parser.get_footnote_at_cursor(0, 1, 1)
      assert.equals(direct.type, facade.type)
      assert.equals(direct.id, facade.id)
    end)
  end)
end)
