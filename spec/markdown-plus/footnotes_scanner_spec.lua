-- Tests for markdown-plus footnotes scanner sub-module
describe("markdown-plus footnotes scanner", function()
  local scanner = require("markdown-plus.footnotes.scanner")
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

  describe("find_all_references", function()
    it("finds references across multiple lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First[^1] ref.",
        "Second[^2] ref.",
      })

      local refs = scanner.find_all_references(0)
      assert.equals(2, #refs)
      assert.equals("1", refs[1].id)
      assert.equals("2", refs[2].id)
    end)

    it("skips references in fenced code blocks", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Real[^1] ref.",
        "```",
        "Fake[^2] ref.",
        "```",
      })

      local refs = scanner.find_all_references(0)
      assert.equals(1, #refs)
      assert.equals("1", refs[1].id)
    end)

    it("returns same results through parser facade", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text[^a] and[^b].",
      })

      local direct = scanner.find_all_references(0)
      local facade = parser.find_all_references(0)
      assert.equals(#direct, #facade)
      assert.equals(direct[1].id, facade[1].id)
    end)
  end)

  describe("find_all_definitions", function()
    it("finds single-line definitions", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^1]: First.",
        "[^2]: Second.",
      })

      local defs = scanner.find_all_definitions(0)
      assert.equals(2, #defs)
    end)

    it("tracks multi-line definition end_line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^1]: Line one",
        "    Line two",
        "    Line three",
      })

      local defs = scanner.find_all_definitions(0)
      assert.equals(1, #defs)
      assert.equals(1, defs[1].line_num)
      assert.equals(3, defs[1].end_line)
    end)

    it("skips definitions in code blocks", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^1]: Real.",
        "```",
        "[^2]: Fake.",
        "```",
      })

      local defs = scanner.find_all_definitions(0)
      assert.equals(1, #defs)
      assert.equals("1", defs[1].id)
    end)
  end)

  describe("find_definition", function()
    it("finds by ID", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[^a]: Alpha.",
        "[^b]: Beta.",
      })

      local def = scanner.find_definition(0, "b")
      assert.is_not_nil(def)
      assert.equals("b", def.id)
    end)

    it("returns nil for missing ID", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "No defs." })

      local def = scanner.find_definition(0, "missing")
      assert.is_nil(def)
    end)
  end)

  describe("find_references", function()
    it("filters by ID", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "A[^1] B[^2] C[^1].",
      })

      local refs = scanner.find_references(0, "1")
      assert.equals(2, #refs)
    end)

    it("returns empty for non-existent ID", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Text[^1]." })

      local refs = scanner.find_references(0, "nope")
      assert.equals(0, #refs)
    end)
  end)
end)
