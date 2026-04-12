-- Tests for markdown-plus format dot-repeat module
describe("markdown-plus format repeat", function()
  local repeat_mod = require("markdown-plus.format.repeat")
  local helpers = require("spec.helpers")

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"

    -- Reset module state before each test
    repeat_mod._repeat_state.format_type = nil
    repeat_mod.set_toggle_module(nil)
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("_toggle_format_with_repeat", function()
    it("sets operatorfunc and returns 'g@l'", function()
      local result = repeat_mod._toggle_format_with_repeat("bold")

      assert.are.equal("g@l", result)
      assert.are.equal("v:lua.require'markdown-plus.format.repeat'._format_operatorfunc", vim.o.operatorfunc)
    end)

    it("saves format_type in _repeat_state", function()
      repeat_mod._toggle_format_with_repeat("strikethrough")

      assert.are.equal("strikethrough", repeat_mod._repeat_state.format_type)
    end)
  end)

  describe("_format_operatorfunc", function()
    it("calls toggle_module.toggle_format_word with saved format_type", function()
      local called_with = nil
      local mock_toggle = {
        toggle_format_word = function(fmt)
          called_with = fmt
        end,
      }

      repeat_mod.set_toggle_module(mock_toggle)
      repeat_mod._repeat_state.format_type = "italic"

      repeat_mod._format_operatorfunc()

      assert.are.equal("italic", called_with)
    end)

    it("returns early when no toggle_module is set (no error)", function()
      repeat_mod.set_toggle_module(nil)
      repeat_mod._repeat_state.format_type = "bold"

      -- Should not error
      assert.has_no.errors(function()
        repeat_mod._format_operatorfunc()
      end)
    end)
  end)

  describe("register_repeat", function()
    it("returns early when repeat.vim is unavailable (no error)", function()
      local exists_stub = helpers.mocks.stub_fn(vim.fn, "exists", function()
        return 0
      end)

      assert.has_no.errors(function()
        repeat_mod.register_repeat("<Plug>(MarkdownPlusBold)")
      end)

      exists_stub.restore()
    end)

    it("schedules repeat#set call when repeat.vim is available", function()
      local schedule_spy = helpers.mocks.mock_schedule()
      local exists_stub = helpers.mocks.stub_fn(vim.fn, "exists", function()
        return 1
      end)

      -- Stub repeat#set to capture the call
      local repeat_set_called = false
      local repeat_set_arg = nil
      vim.fn["repeat#set"] = function(keys)
        repeat_set_called = true
        repeat_set_arg = keys
      end

      repeat_mod.register_repeat("<Plug>(MarkdownPlusBold)")

      -- Callback should be scheduled, not called immediately
      assert.are.equal(1, schedule_spy.calls_count)
      assert.is_false(repeat_set_called)

      -- Flush scheduled callbacks
      schedule_spy.flush()

      assert.is_true(repeat_set_called)
      local expected = vim.api.nvim_replace_termcodes("<Plug>(MarkdownPlusBold)", true, true, true)
      assert.are.equal(expected, repeat_set_arg)

      -- Cleanup
      vim.fn["repeat#set"] = nil
      exists_stub.restore()
      schedule_spy.restore()
    end)
  end)

  describe("_clear_operatorfunc", function()
    it("calls toggle_module.clear_formatting_word", function()
      local called = false
      local mock_toggle = {
        clear_formatting_word = function()
          called = true
        end,
      }

      repeat_mod.set_toggle_module(mock_toggle)

      repeat_mod._clear_operatorfunc()

      assert.is_true(called)
    end)
  end)

  describe("_clear_with_repeat", function()
    it("sets operatorfunc for clear and returns 'g@l'", function()
      local result = repeat_mod._clear_with_repeat()

      assert.are.equal("g@l", result)
      assert.are.equal("v:lua.require'markdown-plus.format.repeat'._clear_operatorfunc", vim.o.operatorfunc)
    end)
  end)
end)
