---Test suite for markdown-plus.nvim TOC state module
---Tests pure state functions: is_expanded, get_children, are_all_ancestors_expanded, build_visible_headers
---@diagnostic disable: undefined-field
local toc_state = require("markdown-plus.headers.toc_state")

describe("markdown-plus toc_state", function()
  before_each(function()
    -- Reset state before each test
    toc_state.state.source_bufnr = nil
    toc_state.state.toc_bufnr = nil
    toc_state.state.toc_winnr = nil
    toc_state.state.headers = {}
    toc_state.state.expanded_levels = {}
    toc_state.state.visible_headers = {}
    toc_state.state.max_depth = toc_state.TOC_DEFAULT_MAX_DEPTH
  end)

  describe("is_expanded", function()
    it("returns false by default", function()
      toc_state.state.headers = { { level = 1, text = "H1", line_num = 1 } }
      assert.is_false(toc_state.is_expanded(1))
    end)

    it("returns true after setting expanded", function()
      toc_state.state.headers = { { level = 1, text = "H1", line_num = 1 } }
      toc_state.state.expanded_levels[1] = true
      assert.is_true(toc_state.is_expanded(1))
    end)

    it("returns false after unsetting expanded", function()
      toc_state.state.headers = { { level = 1, text = "H1", line_num = 1 } }
      toc_state.state.expanded_levels[1] = true
      toc_state.state.expanded_levels[1] = false
      assert.is_false(toc_state.is_expanded(1))
    end)
  end)

  describe("get_children", function()
    it("returns direct children only", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2a", line_num = 2 },
        { level = 3, text = "H3", line_num = 3 },
        { level = 2, text = "H2b", line_num = 4 },
      }

      local children = toc_state.get_children(1)
      assert.are.equal(2, #children)
      assert.are.equal(2, children[1]) -- H2a
      assert.are.equal(4, children[2]) -- H2b
    end)

    it("stops at same level header", function()
      toc_state.state.headers = {
        { level = 1, text = "H1a", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 1, text = "H1b", line_num = 3 },
        { level = 2, text = "H2b", line_num = 4 },
      }

      local children = toc_state.get_children(1)
      assert.are.equal(1, #children)
      assert.are.equal(2, children[1]) -- Only H2 under first H1
    end)

    it("returns empty table for leaf header", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }

      local children = toc_state.get_children(2)
      assert.are.equal(0, #children)
    end)
  end)

  describe("are_all_ancestors_expanded", function()
    it("returns true for H1 (no ancestors)", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
      }

      assert.is_true(toc_state.are_all_ancestors_expanded(1))
    end)

    it("returns false when parent is collapsed", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }
      -- Parent H1 is not expanded (default)
      assert.is_false(toc_state.are_all_ancestors_expanded(2))
    end)

    it("returns true when parent is expanded", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }
      toc_state.state.expanded_levels[1] = true
      assert.is_true(toc_state.are_all_ancestors_expanded(2))
    end)

    it("checks deep nesting correctly", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 3, text = "H3", line_num = 3 },
        { level = 4, text = "H4", line_num = 4 },
      }

      -- All collapsed - H4 should not be visible
      assert.is_false(toc_state.are_all_ancestors_expanded(4))

      -- Expand H1 only - H4 still has collapsed H2, H3
      toc_state.state.expanded_levels[1] = true
      assert.is_false(toc_state.are_all_ancestors_expanded(4))

      -- Expand H1 and H2 - H4 still has collapsed H3
      toc_state.state.expanded_levels[2] = true
      assert.is_false(toc_state.are_all_ancestors_expanded(4))

      -- Expand all ancestors - H4 is now visible
      toc_state.state.expanded_levels[3] = true
      assert.is_true(toc_state.are_all_ancestors_expanded(4))
    end)
  end)

  describe("build_visible_headers", function()
    it("always shows H1 headers", function()
      toc_state.state.headers = {
        { level = 1, text = "H1a", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 1, text = "H1b", line_num = 3 },
      }
      toc_state.state.max_depth = 1

      toc_state.build_visible_headers()

      assert.are.equal(2, #toc_state.state.visible_headers)
      assert.are.equal("H1a", toc_state.state.visible_headers[1].header.text)
      assert.are.equal("H1b", toc_state.state.visible_headers[2].header.text)
    end)

    it("respects max_depth setting", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 3, text = "H3", line_num = 3 },
      }
      toc_state.state.max_depth = 2
      toc_state.state.expanded_levels[1] = true -- Expand H1 so H2 is visible

      toc_state.build_visible_headers()

      local visible_texts = {}
      for _, vh in ipairs(toc_state.state.visible_headers) do
        table.insert(visible_texts, vh.header.text)
      end

      assert.is_true(vim.tbl_contains(visible_texts, "H1"))
      assert.is_true(vim.tbl_contains(visible_texts, "H2"))
      assert.is_false(vim.tbl_contains(visible_texts, "H3"))
    end)

    it("hides headers beyond depth when parent not expanded", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 3, text = "H3", line_num = 3 },
      }
      toc_state.state.max_depth = 2
      toc_state.state.expanded_levels[1] = true -- H1 expanded
      -- H2 NOT expanded

      toc_state.build_visible_headers()

      local visible_texts = {}
      for _, vh in ipairs(toc_state.state.visible_headers) do
        table.insert(visible_texts, vh.header.text)
      end

      assert.is_true(vim.tbl_contains(visible_texts, "H1"))
      assert.is_true(vim.tbl_contains(visible_texts, "H2"))
      assert.is_false(vim.tbl_contains(visible_texts, "H3"))
    end)

    it("shows headers beyond depth when parent is expanded", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
        { level = 3, text = "H3", line_num = 3 },
      }
      toc_state.state.max_depth = 2
      toc_state.state.expanded_levels[1] = true -- H1 expanded
      toc_state.state.expanded_levels[2] = true -- H2 expanded

      toc_state.build_visible_headers()

      local visible_texts = {}
      for _, vh in ipairs(toc_state.state.visible_headers) do
        table.insert(visible_texts, vh.header.text)
      end

      assert.is_true(vim.tbl_contains(visible_texts, "H1"))
      assert.is_true(vim.tbl_contains(visible_texts, "H2"))
      assert.is_true(vim.tbl_contains(visible_texts, "H3"))
    end)

    it("tracks has_children and is_expanded correctly", function()
      toc_state.state.headers = {
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }
      toc_state.state.max_depth = 2
      toc_state.state.expanded_levels[1] = true

      toc_state.build_visible_headers()

      -- H1 has children and is expanded
      assert.is_true(toc_state.state.visible_headers[1].has_children)
      assert.is_true(toc_state.state.visible_headers[1].is_expanded)

      -- H2 has no children and is not expanded
      assert.is_false(toc_state.state.visible_headers[2].has_children)
      assert.is_false(toc_state.state.visible_headers[2].is_expanded)
    end)
  end)
end)
