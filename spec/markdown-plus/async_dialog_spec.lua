describe("markdown-plus delayed dialog source writes", function()
  local code_block = require("markdown-plus.code_block")
  local footnotes = require("markdown-plus.footnotes")
  local mocks = require("spec.helpers.mocks")
  local original_select
  local notify_spy
  local source, source_win, popup, popup_buf, source_path, autosave

  local actions = {
    {
      name = "code block insertion",
      lines = { "source" },
      run = code_block.insert_with_language,
      choice = "lua",
      expected = { "source", "```lua", "", "```" },
    },
    {
      name = "code block visual wrapping",
      lines = { "source" },
      run = function()
        vim.cmd("normal! V")
        code_block.wrap_selection()
      end,
      choice = "lua",
      expected = { "```lua", "source", "```" },
    },
    {
      name = "code block language change",
      lines = { "```python", "source", "```" },
      run = code_block.change_language,
      choice = "lua",
      expected = { "```lua", "source", "```" },
    },
    {
      name = "footnote deletion",
      lines = { "original [^1]", "", "[^1]: original definition" },
      run = footnotes.delete,
      choice = "Yes",
      expected = { "original ", "" },
      col = 11,
    },
  }

  before_each(function()
    original_select = vim.ui.select
    notify_spy = mocks.mock_notify()
    vim.cmd("enew")
    source = vim.api.nvim_get_current_buf()
    source_win = vim.api.nvim_get_current_win()
    source_path = vim.fn.tempname() .. ".md"
    vim.api.nvim_buf_set_name(source, source_path)
    vim.bo.filetype = "markdown"
    code_block.setup({})
    require("markdown-plus.footnotes.insertion").set_confirm_delete(true)
  end)

  after_each(function()
    vim.ui.select = original_select
    notify_spy.restore()
    if autosave then
      vim.api.nvim_del_autocmd(autosave)
      autosave = nil
    end
    if popup and vim.api.nvim_win_is_valid(popup) then
      vim.api.nvim_win_close(popup, true)
    end
    if popup_buf and vim.api.nvim_buf_is_valid(popup_buf) then
      vim.api.nvim_buf_delete(popup_buf, { force = true })
    end
    popup, popup_buf = nil, nil
    if vim.api.nvim_buf_is_valid(source) then
      vim.api.nvim_buf_delete(source, { force = true })
    end
    vim.fn.delete(source_path)
  end)

  for _, action in ipairs(actions) do
    it("allows a write-only event during " .. action.name, function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      vim.api.nvim_win_set_cursor(source_win, { 1, action.col or 0 })
      local complete
      vim.ui.select = function(_, _, callback)
        complete = callback
      end
      action.run()
      local tick = vim.api.nvim_buf_get_changedtick(source)
      vim.cmd("silent write")
      assert.are.same(action.lines, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      assert.is_true(vim.api.nvim_buf_get_changedtick(source) > tick)
      complete(action.choice)
      assert.are.same(action.expected, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      for _, call in ipairs(notify_spy.calls) do
        assert.are_not.equal(vim.log.levels.ERROR, call.level)
      end
    end)

    it("allows BufLeave autosave when a floating picker opens for " .. action.name, function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      vim.api.nvim_win_set_cursor(source_win, { 1, action.col or 0 })
      local saved = false
      autosave = vim.api.nvim_create_autocmd("BufLeave", {
        buffer = source,
        callback = function()
          vim.cmd("silent write")
          saved = true
        end,
      })
      local complete
      vim.ui.select = function(_, _, callback)
        complete = callback
        popup_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, { "picker" })
        popup = vim.api.nvim_open_win(popup_buf, true, {
          relative = "editor",
          row = 1,
          col = 1,
          width = 20,
          height = 1,
        })
      end
      action.run()
      assert.is_true(saved)
      assert.are.same(action.lines, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      complete(action.choice)
      assert.are.same(action.expected, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      assert.are.same({ "picker" }, vim.api.nvim_buf_get_lines(popup_buf, 0, -1, false))
    end)

    it("rejects actual edits followed by a write during " .. action.name, function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      vim.api.nvim_win_set_cursor(source_win, { 1, action.col or 0 })
      local complete
      vim.ui.select = function(_, _, callback)
        complete = callback
      end
      action.run()
      vim.api.nvim_buf_set_lines(source, 0, 0, false, { "new text" })
      local edited = vim.api.nvim_buf_get_lines(source, 0, -1, false)
      vim.cmd("silent write")
      assert.is_false(vim.bo[source].modified)
      complete(action.choice)
      assert.are.same(edited, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      local rejected = false
      for _, call in ipairs(notify_spy.calls) do
        if call.level == vim.log.levels.ERROR and call.msg:match("source buffer changed") then
          rejected = true
        end
      end
      assert.is_true(rejected)
    end)

    it("allows completion after restoring the exact source text during " .. action.name, function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      vim.api.nvim_win_set_cursor(source_win, { 1, action.col or 0 })
      local complete
      vim.ui.select = function(_, _, callback)
        complete = callback
      end
      action.run()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, { "temporary edit" })
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      complete(action.choice)
      assert.are.same(action.expected, vim.api.nvim_buf_get_lines(source, 0, -1, false))
    end)

    it("keeps cancellation non-destructive after a write during " .. action.name, function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, action.lines)
      vim.api.nvim_win_set_cursor(source_win, { 1, action.col or 0 })
      local complete
      vim.ui.select = function(_, _, callback)
        complete = callback
      end
      action.run()
      vim.cmd("silent write")
      complete(nil)
      assert.are.same(action.lines, vim.api.nvim_buf_get_lines(source, 0, -1, false))
      assert.are.same({}, notify_spy.calls)
    end)
  end
end)
