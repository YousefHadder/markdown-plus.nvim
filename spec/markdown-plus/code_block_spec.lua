-- Tests for markdown-plus code block module
describe("markdown-plus code_block", function()
  local code_block = require("markdown-plus.code_block")
  local parser = require("markdown-plus.code_block.parser")
  local navigation = require("markdown-plus.code_block.navigation")
  local original_ui_select

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    original_ui_select = vim.ui.select

    code_block.setup({
      keymaps = { enabled = true },
      code_block = {
        enabled = true,
        fence_style = "backtick",
        languages = { "lua", "python", "bash" },
      },
    })
  end)

  after_each(function()
    vim.ui.select = original_ui_select
    vim.cmd("bdelete!")
  end)

  describe("parser", function()
    it("finds all fenced code blocks", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "intro",
        "```lua",
        "print('hello')",
        "```",
        "",
        "~~~python",
        "print('world')",
        "~~~",
      })

      local blocks = parser.find_all_blocks()
      assert.are.equal(2, #blocks)
      assert.are.equal(2, blocks[1].start_line)
      assert.are.equal(4, blocks[1].end_line)
      assert.are.equal("lua", blocks[1].language)
      assert.are.equal("`", blocks[1].fence_char)
      assert.are.equal(6, blocks[2].start_line)
      assert.are.equal(8, blocks[2].end_line)
      assert.are.equal("python", blocks[2].language)
      assert.are.equal("~", blocks[2].fence_char)
    end)

    it("finds the code block at cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "```lua",
        "print('hello')",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local block = parser.find_block_at_cursor()
      assert.is_not_nil(block)
      assert.are.equal(1, block.start_line)
      assert.are.equal(3, block.end_line)
      assert.are.equal("lua", block.language)
    end)
  end)

  describe("insert and wrap", function()
    it("inserts a fenced code block using language picker", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.select = function(_, _, on_choice)
        on_choice("lua")
      end

      code_block.insert_with_language()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({
        "before",
        "```lua",
        "",
        "```",
        "after",
      }, lines)
    end)

    it("supports asynchronous language pickers", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.select = function(_, _, on_choice)
        vim.defer_fn(function()
          on_choice("lua")
        end, 20)
      end

      code_block.insert_with_language()

      local ok = vim.wait(500, function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        return lines[2] == "```lua"
      end, 10)
      assert.is_true(ok)
    end)

    it("wraps visual selection in fenced code block", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd("normal! Vj")
      vim.ui.select = function(_, _, on_choice)
        on_choice("python")
      end

      code_block.wrap_selection()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({
        "one",
        "```python",
        "two",
        "three",
        "```",
      }, lines)
    end)

    it("respects configured tilde fence style for insertion", function()
      code_block.setup({
        keymaps = { enabled = true },
        code_block = {
          enabled = true,
          fence_style = "tilde",
          languages = { "lua" },
        },
      })

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.select = function(_, _, on_choice)
        on_choice("lua")
      end

      code_block.insert_with_language()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({
        "before",
        "~~~lua",
        "",
        "~~~",
        "after",
      }, lines)
    end)
  end)

  describe("language and navigation", function()
    it("changes language on block under cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "```lua",
        "print('hello')",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.ui.select = function(_, _, on_choice)
        on_choice("bash")
      end

      code_block.change_language()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("```bash", line)
    end)

    it("navigates to next and previous code blocks with wrap-around", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "intro",
        "```lua",
        "print('hello')",
        "```",
        "middle",
        "```python",
        "print('world')",
        "```",
      })

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      navigation.next_block()
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])

      navigation.next_block()
      assert.are.equal(6, vim.api.nvim_win_get_cursor(0)[1])

      navigation.next_block()
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])

      navigation.prev_block()
      assert.are.equal(6, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("toggles fence style on current block", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "```lua",
        "print('hello')",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      code_block.toggle_fence_style()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("~~~lua", lines[1])
      assert.are.equal("~~~", lines[3])
    end)
  end)

  describe("language picker cancellation", function()
    it("does not insert a code block when picker is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.select = function(_, _, on_choice)
        on_choice(nil)
      end

      code_block.insert_with_language()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "before", "after" }, lines)
    end)

    it("does not wrap selection when picker is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd("normal! Vj")
      vim.ui.select = function(_, _, on_choice)
        on_choice(nil)
      end

      code_block.wrap_selection()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "one", "two", "three" }, lines)
    end)

    it("does not change language when picker is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "```lua",
        "print('hello')",
        "```",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.ui.select = function(_, _, on_choice)
        on_choice(nil)
      end

      code_block.change_language()

      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("```lua", line)
    end)
  end)

  describe("custom language via picker", function()
    it("uses custom language when Custom... is selected", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "after" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      -- Select "Custom..." (always last item in the list)
      vim.ui.select = function(items, _, on_choice)
        on_choice(items[#items])
      end
      -- Provide custom language via vim.fn.input
      local orig_input = vim.fn.input
      vim.fn.input = function()
        return "rust"
      end

      code_block.insert_with_language()

      vim.fn.input = orig_input

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({
        "before",
        "```rust",
        "",
        "```",
        "after",
      }, lines)
    end)
  end)

  describe("no code block under cursor", function()
    it("notifies when change_language finds no code block", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_notify = vim.notify
      local warned = false
      vim.notify = function(msg, level)
        if msg:match("No code block under cursor") and level == vim.log.levels.WARN then
          warned = true
        end
      end

      code_block.change_language()

      vim.notify = original_notify
      assert.is_true(warned)
    end)

    it("notifies when toggle_fence_style finds no code block", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_notify = vim.notify
      local warned = false
      vim.notify = function(msg, level)
        if msg:match("No code block under cursor") and level == vim.log.levels.WARN then
          warned = true
        end
      end

      code_block.toggle_fence_style()

      vim.notify = original_notify
      assert.is_true(warned)
    end)
  end)

  describe("keymaps", function()
    it("registers plug mappings and default keymaps", function()
      code_block.enable()

      local insert_plug = vim.fn.maparg("<Plug>(MarkdownPlusCodeBlockInsert)", "n", false, true)
      local change_lang_plug = vim.fn.maparg("<Plug>(MarkdownPlusCodeBlockChangeLanguage)", "n", false, true)
      assert.is_true(next(insert_plug) ~= nil)
      assert.is_true(next(change_lang_plug) ~= nil)

      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlockInsert)", "n") == 1)
      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlockInsert)", "x") == 1)
      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlockNext)", "n") == 1)
      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlockPrev)", "n") == 1)
      assert.is_true(vim.fn.hasmapto("<Plug>(MarkdownPlusCodeBlockChangeLanguage)", "n") == 1)
      assert.are.equal("<Plug>(MarkdownPlusCodeBlockNext)", vim.fn.maparg("]b", "n"))
      assert.are.equal("<Plug>(MarkdownPlusCodeBlockPrev)", vim.fn.maparg("[b", "n"))
    end)
  end)

  describe("navigation edge cases", function()
    it("next_block in empty buffer notifies no blocks found", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "no code blocks here" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_notify = vim.notify
      local notified = false
      vim.notify = function(msg, level)
        if msg:match("No fenced code blocks found") and level == vim.log.levels.INFO then
          notified = true
        end
      end

      local result = navigation.next_block()

      vim.notify = original_notify
      assert.is_false(result)
      assert.is_true(notified)
    end)

    it("prev_block in empty buffer notifies no blocks found", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "no code blocks here" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_notify = vim.notify
      local notified = false
      vim.notify = function(msg, level)
        if msg:match("No fenced code blocks found") and level == vim.log.levels.INFO then
          notified = true
        end
      end

      local result = navigation.prev_block()

      vim.notify = original_notify
      assert.is_false(result)
      assert.is_true(notified)
    end)
  end)
end)
