-- Tests for markdown-plus text formatting module
describe("markdown-plus format", function()
  local format = require("markdown-plus.format")
  local utils = require("markdown-plus.utils")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    format.setup({
      enabled = true,
      features = {
        text_formatting = true,
      },
    })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("has_formatting", function()
    it("detects bold formatting", function()
      assert.is_true(format.has_formatting("**text**", "bold"))
      assert.is_false(format.has_formatting("text", "bold"))
      assert.is_false(format.has_formatting("**text", "bold"))
      assert.is_false(format.has_formatting("text**", "bold"))
    end)

    it("detects italic formatting", function()
      assert.is_true(format.has_formatting("*text*", "italic"))
      assert.is_false(format.has_formatting("text", "italic"))
      assert.is_false(format.has_formatting("*text", "italic"))
    end)

    it("detects strikethrough formatting", function()
      assert.is_true(format.has_formatting("~~text~~", "strikethrough"))
      assert.is_false(format.has_formatting("text", "strikethrough"))
      assert.is_false(format.has_formatting("~~text", "strikethrough"))
    end)

    it("detects inline code formatting", function()
      assert.is_true(format.has_formatting("`text`", "code"))
      assert.is_false(format.has_formatting("text", "code"))
      assert.is_false(format.has_formatting("`text", "code"))
    end)

    it("detects highlight formatting", function()
      assert.is_true(format.has_formatting("==text==", "highlight"))
      assert.is_false(format.has_formatting("text", "highlight"))
      assert.is_false(format.has_formatting("==text", "highlight"))
      assert.is_false(format.has_formatting("text==", "highlight"))
    end)

    it("detects underline formatting", function()
      assert.is_true(format.has_formatting("++text++", "underline"))
      assert.is_false(format.has_formatting("text", "underline"))
      assert.is_false(format.has_formatting("++text", "underline"))
      assert.is_false(format.has_formatting("text++", "underline"))
    end)
  end)

  describe("add_formatting", function()
    it("adds bold formatting", function()
      local result = format.add_formatting("text", "bold")
      assert.equals("**text**", result)
    end)

    it("adds italic formatting", function()
      local result = format.add_formatting("text", "italic")
      assert.equals("*text*", result)
    end)

    it("adds strikethrough formatting", function()
      local result = format.add_formatting("text", "strikethrough")
      assert.equals("~~text~~", result)
    end)

    it("adds inline code formatting", function()
      local result = format.add_formatting("text", "code")
      assert.equals("`text`", result)
    end)

    it("adds highlight formatting", function()
      local result = format.add_formatting("text", "highlight")
      assert.equals("==text==", result)
    end)

    it("adds underline formatting", function()
      local result = format.add_formatting("text", "underline")
      assert.equals("++text++", result)
    end)
  end)

  describe("remove_formatting", function()
    it("removes bold formatting", function()
      local result = format.remove_formatting("**text**", "bold")
      assert.equals("text", result)
    end)

    it("removes italic formatting", function()
      local result = format.remove_formatting("*text*", "italic")
      assert.equals("text", result)
    end)

    it("removes strikethrough formatting", function()
      local result = format.remove_formatting("~~text~~", "strikethrough")
      assert.equals("text", result)
    end)

    it("removes inline code formatting", function()
      local result = format.remove_formatting("`text`", "code")
      assert.equals("text", result)
    end)

    it("removes highlight formatting", function()
      local result = format.remove_formatting("==text==", "highlight")
      assert.equals("text", result)
    end)

    it("removes underline formatting", function()
      local result = format.remove_formatting("++text++", "underline")
      assert.equals("text", result)
    end)

    it("returns unchanged text if no formatting present", function()
      local result = format.remove_formatting("text", "bold")
      assert.equals("text", result)
    end)
  end)

  describe("strip_all_formatting", function()
    it("removes bold formatting", function()
      local result = format.strip_all_formatting("**bold**")
      assert.equals("bold", result)
    end)

    it("removes italic formatting", function()
      local result = format.strip_all_formatting("*italic*")
      assert.equals("italic", result)
    end)

    it("removes strikethrough formatting", function()
      local result = format.strip_all_formatting("~~strike~~")
      assert.equals("strike", result)
    end)

    it("removes code formatting", function()
      local result = format.strip_all_formatting("`code`")
      assert.equals("code", result)
    end)

    it("removes highlight formatting", function()
      local result = format.strip_all_formatting("==highlight==")
      assert.equals("highlight", result)
    end)

    it("removes underline formatting", function()
      local result = format.strip_all_formatting("++underline++")
      assert.equals("underline", result)
    end)

    it("removes multiple formatting types", function()
      local result = format.strip_all_formatting("**bold** and *italic* and `code`")
      assert.equals("bold and italic and code", result)
    end)

    it("removes nested formatting", function()
      local result = format.strip_all_formatting("***bold and italic***")
      assert.equals("bold and italic", result)
    end)

    it("returns unchanged text if no formatting", function()
      local result = format.strip_all_formatting("plain text")
      assert.equals("plain text", result)
    end)
  end)

  describe("get_any_format_at_cursor", function()
    it("returns nil for unformatted text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })

      local result = format.get_any_format_at_cursor()
      assert.is_nil(result)
    end)

    it("detects bold formatting", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold** here" })
      vim.api.nvim_win_set_cursor(0, { 1, 7 })

      local result = format.get_any_format_at_cursor()
      -- If treesitter is available, should return "bold"
      if result then
        assert.equals("bold", result)
      end
    end)

    it("excludes specified format type", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold** here" })
      vim.api.nvim_win_set_cursor(0, { 1, 7 })

      local result = format.get_any_format_at_cursor("bold")
      -- Should return nil because we excluded bold
      assert.is_nil(result)
    end)
  end)

  describe("get_text_in_range", function()
    it("gets text from single line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      local result = utils.get_text_in_range(1, 1, 1, 5)
      assert.equals("hello", result)
    end)

    it("gets text from middle of line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      local result = utils.get_text_in_range(1, 7, 1, 11)
      assert.equals("world", result)
    end)

    it("gets text from multiple lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line one", "line two", "line three" })
      local result = utils.get_text_in_range(1, 6, 2, 4)
      assert.equals("one\nline", result)
    end)
  end)

  describe("set_text_in_range", function()
    it("sets text in single line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      utils.set_text_in_range(1, 1, 1, 5, "goodbye")
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("goodbye world", line)
    end)

    it("sets text in middle of line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      utils.set_text_in_range(1, 7, 1, 11, "universe")
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("hello universe", line)
    end)

    it("validates range order and shows error for invalid range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      utils.set_text_in_range(1, 10, 1, 5, "test")
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("hello world", line)
    end)
  end)

  describe("get_visual_selection", function()
    it("handles forward selection using '< and '> marks (after visual mode)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      -- Simulate visual selection from position 1,1 to 1,5 (after exiting visual mode)
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 1, 5, 0 })
      local selection = utils.get_visual_selection()
      assert.equals(1, selection.start_row)
      assert.equals(1, selection.start_col)
      assert.equals(1, selection.end_row)
      assert.equals(5, selection.end_col)
    end)

    it("handles backward selection using '< and '> marks (after visual mode)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      -- Simulate backward visual selection from position 1,5 to 1,1 (after exiting visual mode)
      vim.fn.setpos("'<", { 0, 1, 5, 0 })
      vim.fn.setpos("'>", { 0, 1, 1, 0 })
      local selection = utils.get_visual_selection()
      -- Should be normalized with start before end
      assert.equals(1, selection.start_row)
      assert.equals(1, selection.start_col)
      assert.equals(1, selection.end_row)
      assert.equals(5, selection.end_col)
    end)

    it("handles multi-line backward selection using '< and '> marks (after visual mode)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line one", "line two" })
      -- Simulate backward selection from line 2 to line 1 (after exiting visual mode)
      vim.fn.setpos("'<", { 0, 2, 5, 0 })
      vim.fn.setpos("'>", { 0, 1, 3, 0 })
      local selection = utils.get_visual_selection()
      -- Should be normalized
      assert.equals(1, selection.start_row)
      assert.equals(3, selection.start_col)
      assert.equals(2, selection.end_row)
      assert.equals(5, selection.end_col)
    end)

    it("handles selection while in visual mode using 'v' mark", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      -- Simulate being in visual mode
      vim.cmd("normal! gg0vllll")
      local selection = utils.get_visual_selection()
      -- Should detect visual mode and use vim.fn.getpos('v') and vim.fn.getpos('.')
      assert.is_not_nil(selection.start_row)
      assert.is_not_nil(selection.start_col)
      assert.is_not_nil(selection.end_row)
      assert.is_not_nil(selection.end_col)
    end)

    it("handles visual line mode (V) by selecting entire lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      -- Simulate being in visual line mode (V)
      vim.cmd("normal! ggV")
      local selection = utils.get_visual_selection()
      -- In line mode, should select from column 1 to end of line
      assert.equals(1, selection.start_row)
      assert.equals(1, selection.start_col)
      assert.equals(1, selection.end_row)
      assert.equals(11, selection.end_col) -- "hello world" has 11 characters
    end)

    it("handles visual line mode (V) with multiple lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line", "third line" })
      -- Simulate visual line mode selecting lines 1-2
      vim.cmd("normal! ggVj")
      local selection = utils.get_visual_selection()
      -- Should select entire lines
      assert.equals(1, selection.start_row)
      assert.equals(1, selection.start_col)
      assert.equals(2, selection.end_row)
      assert.equals(11, selection.end_col) -- "second line" has 11 characters
    end)
  end)

  describe("patterns", function()
    it("has bold pattern", function()
      assert.is_not_nil(format.patterns.bold)
      assert.equals("**", format.patterns.bold.wrap)
    end)

    it("has italic pattern", function()
      assert.is_not_nil(format.patterns.italic)
      assert.equals("*", format.patterns.italic.wrap)
    end)

    it("has strikethrough pattern", function()
      assert.is_not_nil(format.patterns.strikethrough)
      assert.equals("~~", format.patterns.strikethrough.wrap)
    end)

    it("has code pattern", function()
      assert.is_not_nil(format.patterns.code)
      assert.equals("`", format.patterns.code.wrap)
    end)

    it("has highlight pattern", function()
      assert.is_not_nil(format.patterns.highlight)
      assert.equals("==", format.patterns.highlight.wrap)
    end)

    it("has underline pattern", function()
      assert.is_not_nil(format.patterns.underline)
      assert.equals("++", format.patterns.underline.wrap)
    end)
  end)
  describe("convert_to_code_block", function()
    local original_input

    before_each(function()
      -- Save original vim.fn.input
      original_input = vim.fn.input
    end)

    after_each(function()
      -- Restore original vim.fn.input
      vim.fn.input = original_input
    end)

    it("converts selected lines to a code block", function()
      -- Set buffer lines for testing
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })

      -- Select lines 2-3 (1-based index)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd("normal! Vj") -- Enter visual line mode and select down one line

      -- Mock vim.fn.input to simulate user input
      vim.fn.input = function()
        return "lua"
      end

      -- Call the function to convert selection to a code block
      format.convert_to_code_block()

      -- Get the buffer lines after conversion
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      -- Verify the buffer contains the expected lines
      assert.are.equal("First line", lines[1])
      assert.are.equal("```lua", lines[2])
      assert.are.equal("Second line", lines[3])
      assert.are.equal("Third line", lines[4])
      assert.are.equal("```", lines[5])
    end)

    it("does not modify empty lines", function()
      -- Set buffer lines with empty lines for testing
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "",
        "Second line",
        "",
      })

      -- Select all lines (1-3, 1-based index)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! Vjj") -- Enter visual line mode and select down two lines

      -- Mock vim.fn.input to simulate user input
      vim.fn.input = function()
        return "lua"
      end

      -- Call the function to convert selection to a code block
      format.convert_to_code_block()

      -- Get the buffer lines after conversion
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      -- Verify the buffer contains the expected lines
      assert.are.equal("```lua", lines[1])
      assert.are.equal("", lines[2])
      assert.are.equal("Second line", lines[3])
      assert.are.equal("", lines[4])
      assert.are.equal("```", lines[5])
    end)
  end)

  describe("utils get_visual_selection", function()
    it("returns correct selection range for line-wise visual mode", function()
      -- Set buffer lines for testing
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })

      -- Select lines 2-3 (1-based index)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd("normal! Vj") -- Enter visual line mode and select down one line

      -- Get the visual selection range
      local selection = utils.get_visual_selection()

      -- Verify the selection range is correct
      assert.are.equal(2, selection.start_row)
      assert.are.equal(3, selection.end_row)
    end)
  end)

  describe("setup_keymaps", function()
    it("creates <Plug> mappings even when keymaps.enabled is false", function()
      format.setup({
        keymaps = {
          enabled = false,
        },
      })
      format.setup_keymaps()
      -- Verify that <Plug> mapping exists (can be checked with maparg)
      local plug_mapping = vim.fn.maparg("<Plug>(MarkdownPlusCodeBlock)", "x", false, true)
      assert.is_not_nil(plug_mapping)
      assert.is_true(next(plug_mapping) ~= nil)
      -- Verify that no default keymap is set (hasmapto checks for mappings TO the <Plug>)
      assert.is_false(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlock)", "x") == 1)
    end)

    it("sets up the <Plug> mapping correctly", function()
      format.setup({ keymaps = { enabled = true } })
      format.setup_keymaps()
      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlock)", "x") == 1)
    end)
  end)

  describe("get_lines_in_range", function()
    it("returns the correct lines for a valid range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })
      local lines = format.get_lines_in_range(1, 2) -- 1-based index
      assert.are.same({ "First line", "Second line" }, lines)
    end)

    it("returns an empty list for an out-of-bounds range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "First line" })
      local lines = format.get_lines_in_range(2, 3) -- 1-based index
      assert.are.same({}, lines)
    end)
  end)

  describe("convert_to_format with backward selection", function()
    local original_input

    before_each(function()
      original_input = vim.fn.input
    end)

    after_each(function()
      vim.fn.input = original_input
    end)

    it("correctly handles backward visual selection", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })

      -- Select from line 3 to line 2 (backward)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.cmd("normal! Vk") -- Enter visual line mode and select up one line

      vim.fn.input = function()
        return "lua"
      end

      format.convert_to_code_block()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      -- The buffer should now contain:
      -- 1. First line (unchanged)
      -- 2. ```lua (inserted before selection)
      -- 3. Second line
      -- 4. Third line
      -- 5. ``` (inserted after selection)
      assert.are.equal("First line", lines[1])
      assert.are.equal("```lua", lines[2])
      assert.are.equal("Second line", lines[3])
      assert.are.equal("Third line", lines[4])
      assert.are.equal("```", lines[5])
    end)
  end)

  describe("convert_to_code_block without user input", function()
    local original_input

    before_each(function()
      original_input = vim.fn.input
    end)

    after_each(function()
      vim.fn.input = original_input
    end)

    it("shows a warning and does not insert code block markers", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! Vj")
      vim.fn.input = function()
        return ""
      end
      format.convert_to_code_block()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Verify that no markers were inserted
      assert.are.equal("First line", lines[1])
      assert.are.equal("Second line", lines[2])
    end)
  end)

  describe("enable", function()
    it("does nothing if buffer is not markdown", function()
      vim.bo.filetype = "text"
      format.enable()
      -- No direct way to verify this without mocking/spying, but the function should exit early
    end)
  end)

  describe("utils get_visual_selection in block mode", function()
    it("returns the correct selection range for multi-line visual mode", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "First line",
        "Second line",
        "Third line",
      })

      -- Select lines 1-2 (1-based index) in line-wise visual mode
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! Vj") -- Enter visual line mode and select down one line

      local selection = utils.get_visual_selection()

      -- Verify the selection range is correct
      assert.are.equal(1, selection.start_row)
      assert.are.equal(2, selection.end_row)
    end)
  end)

  describe("UTF-8 handling", function()
    -- Basic tests that verify UTF-8 text doesn't crash the plugin

    it("doesn't crash with emoji in text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Hello 👋 world" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      -- Should not crash
      local success = pcall(function()
        format.get_word_boundaries()
      end)
      assert.is_true(success)
    end)

    it("doesn't crash with accented characters", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "café naïve résumé" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      local success = pcall(function()
        format.get_word_boundaries()
      end)
      assert.is_true(success)
    end)

    it("doesn't crash with CJK characters", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "你好 世界 test" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local success = pcall(function()
        format.get_word_boundaries()
      end)
      assert.is_true(success)
    end)

    it("can format simple ASCII text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local success = pcall(function()
        format.toggle_format_word("bold")
      end)
      assert.is_true(success)

      local line = utils.get_current_line()
      -- Should have bold formatting
      assert.matches("%*%*", line)
    end)
  end)

  describe("treesitter node type mappings", function()
    it("has bold node type mapping", function()
      assert.equals("strong_emphasis", format.ts_node_types.bold)
    end)

    it("has italic node type mapping", function()
      assert.equals("emphasis", format.ts_node_types.italic)
    end)

    it("has strikethrough node type mapping", function()
      assert.equals("strikethrough", format.ts_node_types.strikethrough)
    end)

    it("has code node type mapping", function()
      assert.equals("code_span", format.ts_node_types.code)
    end)

    it("does not have highlight node type (not supported by treesitter)", function()
      assert.is_nil(format.ts_node_types.highlight)
    end)

    it("does not have underline node type (not supported by treesitter)", function()
      assert.is_nil(format.ts_node_types.underline)
    end)
  end)

  describe("get_formatting_node_at_cursor", function()
    it("returns nil for unsupported format types", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "==highlight==" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local result = format.get_formatting_node_at_cursor("highlight")
      assert.is_nil(result)
    end)

    it("returns nil for unformatted text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })

      local result = format.get_formatting_node_at_cursor("bold")
      assert.is_nil(result)
    end)

    -- Treesitter detection tests (requires markdown_inline parser)
    -- These tests verify the integration with treesitter when available

    it("detects bold formatting at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "**bold text**" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Cursor on "bold"

      local result = format.get_formatting_node_at_cursor("bold")
      -- If treesitter is available, should return node info
      if result then
        assert.equals(1, result.start_row)
        assert.equals(1, result.start_col)
        assert.equals(1, result.end_row)
        assert.equals(13, result.end_col)
      end
      -- If treesitter not available, result is nil which is fine
    end)

    it("detects italic formatting at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "*italic text*" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Cursor on "italic"

      local result = format.get_formatting_node_at_cursor("italic")
      if result then
        assert.equals(1, result.start_row)
        assert.equals(1, result.start_col)
        assert.equals(1, result.end_row)
        assert.equals(13, result.end_col)
      end
    end)

    it("detects code formatting at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "`code text`" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- Cursor on "code"

      local result = format.get_formatting_node_at_cursor("code")
      if result then
        assert.equals(1, result.start_row)
        assert.equals(1, result.start_col)
        assert.equals(1, result.end_row)
        assert.equals(11, result.end_col)
      end
    end)

    it("detects strikethrough formatting at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "~~strike text~~" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Cursor on "strike"

      local result = format.get_formatting_node_at_cursor("strikethrough")
      if result then
        assert.equals(1, result.start_row)
        assert.equals(1, result.start_col)
        assert.equals(1, result.end_row)
        assert.equals(15, result.end_col)
      end
    end)
  end)

  describe("remove_formatting_from_node", function()
    it("removes bold formatting from node range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "**bold text**" })
      local node_info = {
        start_row = 1,
        start_col = 1,
        end_row = 1,
        end_col = 13,
      }

      local success = format.remove_formatting_from_node(node_info, "bold")
      assert.is_true(success)

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("bold text", line)
    end)

    it("removes italic formatting from node range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "*italic text*" })
      local node_info = {
        start_row = 1,
        start_col = 1,
        end_row = 1,
        end_col = 13,
      }

      local success = format.remove_formatting_from_node(node_info, "italic")
      assert.is_true(success)

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("italic text", line)
    end)

    it("removes code formatting from node range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "`code text`" })
      local node_info = {
        start_row = 1,
        start_col = 1,
        end_row = 1,
        end_col = 11,
      }

      local success = format.remove_formatting_from_node(node_info, "code")
      assert.is_true(success)

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("code text", line)
    end)

    it("returns false for invalid format type", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "some text" })
      local node_info = {
        start_row = 1,
        start_col = 1,
        end_row = 1,
        end_col = 9,
      }

      local success = format.remove_formatting_from_node(node_info, "invalid_format")
      assert.is_false(success)
    end)
  end)

  describe("toggle_format_word with treesitter", function()
    it("removes formatting when cursor is inside formatted range (via treesitter)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold text** here" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- Cursor on "bold"

      format.toggle_format_word("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Treesitter removes entire bold range, result should be unformatted
      assert.equals("Some bold text here", line)
    end)

    it("adds formatting when cursor is on unformatted word", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- Cursor on "text"

      format.toggle_format_word("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should have bold formatting on "text"
      assert.matches("%*%*text%*%*", line)
    end)

    it("falls back to word-based logic for unsupported formats (highlight)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- Cursor on "text"

      format.toggle_format_word("highlight")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should have highlight formatting on "text"
      assert.matches("==text==", line)
    end)

    it("falls back to word-based logic for unsupported formats (underline)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- Cursor on "text"

      format.toggle_format_word("underline")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should have underline formatting on "text"
      assert.matches("%+%+text%+%+", line)
    end)

    it("preserves cursor position on same character after removing formatting", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold text** here" })
      -- Position cursor on 'l' in "bold" (col 9, 0-indexed)
      vim.api.nvim_win_set_cursor(0, { 1, 9 })

      local cursor_before = vim.api.nvim_win_get_cursor(0)
      local line_before = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local char_before = line_before:sub(cursor_before[2] + 1, cursor_before[2] + 1)

      format.toggle_format_word("bold")

      local cursor_after = vim.api.nvim_win_get_cursor(0)
      local line_after = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local char_after = line_after:sub(cursor_after[2] + 1, cursor_after[2] + 1)

      -- Cursor should stay on the same character
      assert.equals(char_before, char_after)
      assert.equals("l", char_after)
    end)

    it("preserves cursor position on same character after adding formatting", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some text here" })
      -- Position cursor on 'x' in "text" (col 7, 0-indexed)
      vim.api.nvim_win_set_cursor(0, { 1, 7 })

      local cursor_before = vim.api.nvim_win_get_cursor(0)
      local line_before = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local char_before = line_before:sub(cursor_before[2] + 1, cursor_before[2] + 1)

      format.toggle_format_word("bold")

      local cursor_after = vim.api.nvim_win_get_cursor(0)
      local line_after = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local char_after = line_after:sub(cursor_after[2] + 1, cursor_after[2] + 1)

      -- Cursor should stay on the same character
      assert.equals(char_before, char_after)
      assert.equals("x", char_after)
      -- Line should have bold formatting
      assert.equals("Some **text** here", line_after)
    end)

    it("adds italic to bold word (nested formatting)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold** here" })
      vim.api.nvim_win_set_cursor(0, { 1, 7 }) -- Cursor on "bold"

      format.toggle_format_word("italic")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should add italic around the bold word: ***bold***
      assert.equals("Some ***bold*** here", line)
    end)

    it("adds bold to italic word (nested formatting)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some *italic* here" })
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- Cursor on "italic"

      format.toggle_format_word("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should add bold around the italic word: ***italic***
      assert.equals("Some ***italic*** here", line)
    end)

    it("adds code to bold word (nested formatting)", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold** here" })
      vim.api.nvim_win_set_cursor(0, { 1, 7 }) -- Cursor on "bold"

      format.toggle_format_word("code")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      -- Should add code around the bold word: `**bold**`
      assert.equals("Some `**bold**` here", line)
    end)
  end)

  describe("toggle_format (visual mode) with treesitter", function()
    it("removes formatting when selection is inside formatted range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold text** here" })

      -- Simulate visual selection of "bold text" only (inside the **)
      vim.fn.setpos("'<", { 0, 1, 8, 0 })
      vim.fn.setpos("'>", { 0, 1, 16, 0 })

      format.toggle_format("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("Some bold text here", line)
    end)

    it("removes formatting when selection includes markers", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some **bold text** here" })

      -- Simulate visual selection including ** markers
      vim.fn.setpos("'<", { 0, 1, 6, 0 })
      vim.fn.setpos("'>", { 0, 1, 18, 0 })

      format.toggle_format("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("Some bold text here", line)
    end)

    it("adds formatting to unformatted selection", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some plain text here" })

      -- Simulate visual selection of "plain"
      vim.fn.setpos("'<", { 0, 1, 6, 0 })
      vim.fn.setpos("'>", { 0, 1, 10, 0 })

      format.toggle_format("bold")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("Some **plain** text here", line)
    end)

    it("removes italic when selection is inside italic range", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some *italic text* here" })

      -- Simulate visual selection of "italic" only
      vim.fn.setpos("'<", { 0, 1, 7, 0 })
      vim.fn.setpos("'>", { 0, 1, 12, 0 })

      format.toggle_format("italic")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("Some italic text here", line)
    end)

    it("removes code when selection is inside code span", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Some `inline code` here" })

      -- Simulate visual selection of "inline" only
      vim.fn.setpos("'<", { 0, 1, 7, 0 })
      vim.fn.setpos("'>", { 0, 1, 12, 0 })

      format.toggle_format("code")

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.equals("Some inline code here", line)
    end)
  end)
end)
