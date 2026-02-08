-- Tests for markdown-plus footnotes module
describe("markdown-plus footnotes", function()
  local parser = require("markdown-plus.footnotes.parser")
  local footnotes = require("markdown-plus.footnotes")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    -- Setup with full config structure
    footnotes.setup({
      footnotes = {
        section_header = "Footnotes",
        confirm_delete = false, -- Disable confirmation for tests
      },
    })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("parser", function()
    describe("parse_reference_at_cursor", function()
      it("detects footnote reference at cursor", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text[^1] here." })
        vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- cursor on [^1]

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local ref = parser.parse_reference_at_cursor(line, 11)
        assert.is_not_nil(ref)
        assert.equals("1", ref.id)
      end)

      it("detects text ID reference", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text[^example] here." })
        vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- cursor on [^example]

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local ref = parser.parse_reference_at_cursor(line, 11)
        assert.is_not_nil(ref)
        assert.equals("example", ref.id)
      end)

      it("returns nil when not on reference", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text without footnote." })
        vim.api.nvim_win_set_cursor(0, { 1, 5 })

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local ref = parser.parse_reference_at_cursor(line, 6)
        assert.is_nil(ref)
      end)
    end)

    describe("parse_definition", function()
      it("detects footnote definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: This is the footnote." })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local def = parser.parse_definition(line)
        assert.is_not_nil(def)
        assert.equals("1", def.id)
        assert.equals("This is the footnote.", def.content)
      end)

      it("detects text ID definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^example]: Example footnote." })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local def = parser.parse_definition(line)
        assert.is_not_nil(def)
        assert.equals("example", def.id)
      end)

      it("returns nil when not on definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Regular text." })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        local def = parser.parse_definition(line)
        assert.is_nil(def)
      end)
    end)

    describe("find_all_references", function()
      it("finds all references in buffer", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "First[^1] and second[^2].",
          "Another[^1] reference.",
        })

        local refs = parser.find_all_references(0)
        assert.equals(3, #refs)
      end)

      it("returns empty array when no references", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text without footnotes.",
        })

        local refs = parser.find_all_references(0)
        assert.equals(0, #refs)
      end)

      it("ignores references inside fenced code blocks with backticks", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Real reference[^1] here.",
          "```",
          "Code with [^fake] reference",
          "```",
          "More text[^2].",
        })

        local refs = parser.find_all_references(0)
        assert.equals(2, #refs)
        assert.equals("1", refs[1].id)
        assert.equals("2", refs[2].id)
      end)

      it("ignores references inside fenced code blocks with tildes", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Real reference[^1] here.",
          "~~~",
          "Code with [^fake] reference",
          "~~~",
          "More text.",
        })

        local refs = parser.find_all_references(0)
        assert.equals(1, #refs)
        assert.equals("1", refs[1].id)
      end)

      it("ignores references inside inline code", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Real[^1] and `inline [^fake] code` here.",
          "Also ``double [^fake2] backticks`` work.",
        })

        local refs = parser.find_all_references(0)
        assert.equals(1, #refs)
        assert.equals("1", refs[1].id)
      end)
    end)

    describe("find_all_definitions", function()
      it("finds all definitions in buffer", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Content here.",
          "",
          "[^1]: First footnote.",
          "[^2]: Second footnote.",
        })

        local defs = parser.find_all_definitions(0)
        assert.equals(2, #defs)
      end)

      it("finds multi-line definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "[^1]: First line",
          "    Second line",
          "    Third line",
          "",
          "Other content",
        })

        local defs = parser.find_all_definitions(0)
        assert.equals(1, #defs)
        assert.equals(1, defs[1].line_num)
        assert.equals(3, defs[1].end_line)
      end)

      it("ignores definitions inside fenced code blocks", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "[^1]: Real definition.",
          "```",
          "[^fake]: Not a real definition",
          "```",
          "[^2]: Another real one.",
        })

        local defs = parser.find_all_definitions(0)
        assert.equals(2, #defs)
        assert.equals("1", defs[1].id)
        assert.equals("2", defs[2].id)
      end)
    end)

    describe("get_all_footnotes", function()
      it("returns combined footnote info", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text with[^1] footnote.",
          "",
          "[^1]: Definition here.",
        })

        local all = parser.get_all_footnotes(0)
        assert.equals(1, #all)
        assert.equals("1", all[1].id)
        assert.is_not_nil(all[1].definition)
        assert.equals(1, #all[1].references)
      end)

      it("detects orphan footnotes", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text without reference.",
          "",
          "[^1]: Orphan footnote.",
        })

        local all = parser.get_all_footnotes(0)
        assert.equals(1, #all)
        assert.equals(0, #all[1].references)
      end)

      it("detects missing definitions", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text with[^1] missing definition.",
        })

        local all = parser.get_all_footnotes(0)
        assert.equals(1, #all)
        assert.is_nil(all[1].definition)
      end)
    end)

    describe("get_next_numeric_id", function()
      it("returns 1 when no footnotes exist", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "No footnotes." })

        local next_id = parser.get_next_numeric_id(0)
        assert.equals("1", next_id)
      end)

      it("returns next number after highest", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text[^1] and[^3].",
          "[^1]: Def",
          "[^3]: Def",
        })

        local next_id = parser.get_next_numeric_id(0)
        assert.equals("4", next_id)
      end)

      it("ignores non-numeric IDs", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text[^example] here.",
          "[^example]: Definition.",
        })

        local next_id = parser.get_next_numeric_id(0)
        assert.equals("1", next_id)
      end)
    end)

    describe("find_definition", function()
      it("finds definition by ID", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text.",
          "[^test]: The definition.",
        })

        local def = parser.find_definition(0, "test")
        assert.is_not_nil(def)
        assert.equals("test", def.id)
        assert.equals("The definition.", def.content)
      end)

      it("returns nil for non-existent definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "No definitions." })

        local def = parser.find_definition(0, "missing")
        assert.is_nil(def)
      end)
    end)

    describe("find_references", function()
      it("finds all references by ID", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "First[^1] and again[^1].",
          "And[^2] a different one.",
        })

        local refs = parser.find_references(0, "1")
        assert.equals(2, #refs)
      end)

      it("returns empty array for non-existent ID", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "No refs." })

        local refs = parser.find_references(0, "missing")
        assert.equals(0, #refs)
      end)
    end)

    describe("find_footnotes_section", function()
      it("finds section header line", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Content.",
          "",
          "## Footnotes",
          "",
          "[^1]: Definition.",
        })

        local line = parser.find_footnotes_section(0, "Footnotes")
        assert.equals(3, line)
      end)

      it("returns nil when no section exists", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Just content.",
          "[^1]: Definition.",
        })

        local line = parser.find_footnotes_section(0, "Footnotes")
        assert.is_nil(line)
      end)
    end)

    describe("get_definition_range", function()
      it("returns range for single-line definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "[^1]: Single line.",
          "",
          "Other content.",
        })

        local start_line, end_line = parser.get_definition_range(0, 1)
        assert.equals(1, start_line)
        assert.equals(1, end_line)
      end)

      it("returns range for multi-line definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "[^1]: First line",
          "    Second line",
          "    Third line",
          "",
          "Other content.",
        })

        local start_line, end_line = parser.get_definition_range(0, 1)
        assert.equals(1, start_line)
        assert.equals(3, end_line)
      end)
    end)
  end)

  describe("module API", function()
    describe("get_all_footnotes", function()
      it("delegates to parser", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text[^1] here.",
          "[^1]: Definition.",
        })

        local all = footnotes.get_all_footnotes()
        assert.equals(1, #all)
      end)
    end)

    describe("get_next_id", function()
      it("delegates to parser", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text[^5] here.",
          "[^5]: Definition.",
        })

        local next_id = footnotes.get_next_id()
        assert.equals("6", next_id)
      end)
    end)

    describe("get_footnote_at_cursor", function()
      it("returns reference when on reference", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Text[^1] here." })
        vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- on [^1]

        local fn = footnotes.get_footnote_at_cursor()
        assert.is_not_nil(fn)
        assert.equals("1", fn.id)
      end)

      it("returns definition when on definition", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[^1]: Definition text." })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        local fn = footnotes.get_footnote_at_cursor()
        assert.is_not_nil(fn)
        assert.equals("1", fn.id)
      end)

      it("returns nil when not on footnote", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Plain text." })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        local fn = footnotes.get_footnote_at_cursor()
        assert.is_nil(fn)
      end)
    end)
  end)

  describe("configuration", function()
    it("merges user config with defaults", function()
      footnotes.setup({
        footnotes = {
          section_header = "Notes",
        },
      })

      local config = footnotes.get_config()
      assert.equals("Notes", config.section_header)
      -- Default values should still be present
      assert.equals(true, config.confirm_delete)
    end)

    it("uses default config when no opts provided", function()
      footnotes.setup({})

      local config = footnotes.get_config()
      assert.equals("Footnotes", config.section_header)
      assert.equals(true, config.confirm_delete)
    end)
  end)

  describe("navigation", function()
    local navigation = require("markdown-plus.footnotes.navigation")

    describe("goto_definition", function()
      it("jumps to footnote definition from reference", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text with[^1] footnote.",
          "",
          "[^1]: The definition.",
        })
        vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- on [^1]

        navigation.goto_definition()

        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.equals(3, cursor[1])
      end)

      it("does not error when definition line is out of range", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "Text with[^1] footnote.",
          "",
          "[^1]: The definition.",
        })
        vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- on [^1]

        -- Stub nvim_buf_get_lines to return empty (simulating buffer shrink)
        local orig_get_lines = vim.api.nvim_buf_get_lines
        vim.api.nvim_buf_get_lines = function(buf, start, stop, strict)
          -- Only intercept the single-line read for the definition
          if start == 2 and stop == 3 then
            return {}
          end
          return orig_get_lines(buf, start, stop, strict)
        end

        local success = pcall(function()
          navigation.goto_definition()
        end)

        vim.api.nvim_buf_get_lines = orig_get_lines
        assert.is_true(success, "goto_definition should not error when line is nil")
      end)
    end)
  end)
end)
