---Test suite for markdown-plus.nvim TOC actions module
---Tests user interaction functions: expand_header, collapse_header, jump_to_header
---@diagnostic disable: undefined-field
local toc_state = require("markdown-plus.headers.toc_state")
local toc_actions = require("markdown-plus.headers.toc_actions")

---Helper to set up toc_state with headers and build visible headers
---@param headers table[] Headers to set
---@param expanded table<number, boolean>|nil Which headers to expand
---@param max_depth number|nil Max depth (default: 2)
local function setup_state(headers, expanded, max_depth)
  toc_state.state.headers = headers
  toc_state.state.expanded_levels = expanded or {}
  toc_state.state.max_depth = max_depth or toc_state.TOC_DEFAULT_MAX_DEPTH
  toc_state.build_visible_headers()
end

describe("markdown-plus toc_actions", function()
  local toc_bufnr

  before_each(function()
    -- Reset state
    toc_state.state.source_bufnr = vim.api.nvim_get_current_buf()
    toc_state.state.toc_winnr = vim.api.nvim_get_current_win()
    toc_state.state.headers = {}
    toc_state.state.expanded_levels = {}
    toc_state.state.visible_headers = {}
    toc_state.state.max_depth = toc_state.TOC_DEFAULT_MAX_DEPTH

    -- Create a scratch buffer to act as the TOC buffer
    toc_bufnr = vim.api.nvim_create_buf(false, true)
    toc_state.state.toc_bufnr = toc_bufnr
    vim.api.nvim_win_set_buf(0, toc_bufnr)
    vim.bo[toc_bufnr].modifiable = true
  end)

  after_each(function()
    -- Clean up scratch buffer
    if toc_bufnr and vim.api.nvim_buf_is_valid(toc_bufnr) then
      vim.api.nvim_buf_delete(toc_bufnr, { force = true })
    end
  end)

  describe("expand_header", function()
    it("does nothing when cursor is out of bounds", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
      }, { [1] = false }, 1)

      -- Set buffer lines so cursor can be positioned
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "H1" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Manually clear visible_headers to simulate out-of-bounds
      toc_state.state.visible_headers = {}

      toc_actions.expand_header()

      -- Should not crash and expanded_levels should be unchanged
      assert.is_false(toc_state.is_expanded(1))
    end)

    it("does nothing for headers with no children", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }, { [1] = true }, 2)

      -- Set buffer lines to match visible headers count
      local lines = {}
      for i = 1, #toc_state.state.visible_headers do
        lines[i] = "line " .. i
      end
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, lines)

      -- Position cursor on H2 (leaf node, no children)
      local h2_line = nil
      for i, vh in ipairs(toc_state.state.visible_headers) do
        if vh.header.text == "H2" then
          h2_line = i
          break
        end
      end

      assert.is_not_nil(h2_line)
      vim.api.nvim_win_set_cursor(0, { h2_line, 0 })

      toc_actions.expand_header()

      -- H2 should not be marked as expanded (it has no children)
      assert.is_false(toc_state.is_expanded(2))
    end)

    it("marks header as expanded when it has children", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }, {}, 1)

      -- Set buffer lines
      local lines = {}
      for i = 1, #toc_state.state.visible_headers do
        lines[i] = "line " .. i
      end
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, lines)

      -- Position cursor on H1 (has children)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- H1 should not be expanded yet
      assert.is_false(toc_state.is_expanded(1))

      toc_actions.expand_header()

      -- H1 should now be expanded
      assert.is_true(toc_state.is_expanded(1))
    end)
  end)

  describe("collapse_header", function()
    it("does nothing when cursor is out of bounds", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
      }, { [1] = true }, 1)

      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "H1" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Clear visible headers to simulate out-of-bounds
      toc_state.state.visible_headers = {}

      toc_actions.collapse_header()

      -- Should not crash
      assert.is_true(toc_state.is_expanded(1))
    end)

    it("collapses an expanded header", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }, { [1] = true }, 2)

      local lines = {}
      for i = 1, #toc_state.state.visible_headers do
        lines[i] = "line " .. i
      end
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, lines)

      -- Position cursor on H1 (expanded)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      assert.is_true(toc_state.is_expanded(1))

      toc_actions.collapse_header()

      -- H1 should now be collapsed
      assert.is_false(toc_state.is_expanded(1))
    end)

    it("finds and collapses parent when header is not expanded", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }, { [1] = true }, 2)

      local lines = {}
      for i = 1, #toc_state.state.visible_headers do
        lines[i] = "line " .. i
      end
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, lines)

      -- Position cursor on H2 (not expanded, child of H1)
      local h2_line = nil
      for i, vh in ipairs(toc_state.state.visible_headers) do
        if vh.header.text == "H2" then
          h2_line = i
          break
        end
      end

      assert.is_not_nil(h2_line)
      vim.api.nvim_win_set_cursor(0, { h2_line, 0 })

      -- H1 is expanded
      assert.is_true(toc_state.is_expanded(1))

      toc_actions.collapse_header()

      -- Parent H1 should now be collapsed
      assert.is_false(toc_state.is_expanded(1))
    end)
  end)

  describe("expand_header", function()
    it("does nothing when cursor line exceeds visible headers count", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
        { level = 2, text = "H2", line_num = 2 },
      }, {}, 1)

      -- Put 3 lines in buffer so cursor can go to line 3
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "H1", "H2", "extra" })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      -- visible_headers only has entries for lines 1-2 at most; line 3 is beyond
      local before = vim.deepcopy(toc_state.state.expanded_levels)
      toc_actions.expand_header()
      assert.are.same(before, toc_state.state.expanded_levels)
    end)
  end)

  describe("collapse_header", function()
    it("on a leaf header without a parent is a no-op", function()
      -- Single top-level header that is not expanded and has no parent
      setup_state({
        { level = 1, text = "Solo", line_num = 1 },
      }, {}, 1)

      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "Solo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local before = vim.deepcopy(toc_state.state.expanded_levels)
      toc_actions.collapse_header()
      -- No parent to collapse, expanded_levels unchanged
      assert.are.same(before, toc_state.state.expanded_levels)
    end)
  end)

  describe("jump_to_header", function()
    it("does nothing when cursor is out of bounds", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
      }, {}, 1)

      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "H1" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Clear visible headers to simulate out-of-bounds
      toc_state.state.visible_headers = {}

      -- Should not crash
      toc_actions.jump_to_header()
    end)

    it("does nothing when cursor line exceeds visible headers count", function()
      setup_state({
        { level = 1, text = "H1", line_num = 1 },
      }, {}, 1)

      -- Put 2 lines in buffer so cursor can go to line 2
      vim.api.nvim_buf_set_lines(toc_bufnr, 0, -1, false, { "H1", "extra" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      -- visible_headers has only 1 entry; cursor on line 2 is beyond
      local win_before = vim.api.nvim_get_current_win()
      toc_actions.jump_to_header()
      -- Window should not change (no jump occurred)
      assert.equals(win_before, vim.api.nvim_get_current_win())
    end)
  end)

  describe("setup_toc_keymaps", function()
    it("registers plug mappings for TOC actions", function()
      local config = {
        keymaps = { enabled = true },
      }

      toc_actions.setup_toc_keymaps(config)

      -- Verify that <Plug>(MarkdownPlusTocExpand) is registered in normal mode
      local expand_map = vim.fn.maparg("<Plug>(MarkdownPlusTocExpand)", "n", false, true)
      assert.is_truthy(expand_map)
      assert.is_not.equals("", expand_map.lhs or "")

      -- Verify <Plug>(MarkdownPlusTocJump) exists
      local jump_map = vim.fn.maparg("<Plug>(MarkdownPlusTocJump)", "n", false, true)
      assert.is_truthy(jump_map)
      assert.is_not.equals("", jump_map.lhs or "")
    end)
  end)
end)
