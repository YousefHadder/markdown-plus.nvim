---Test suite for markdown-plus.nvim list auto-renumber autocommands
---Tests the extracted autocmds sub-module: helpers, autocommand registration,
---callback behavior, and teardown of timers and augroups.
---@diagnostic disable: undefined-field
local autocmds = require("markdown-plus.list.autocmds")

local AUGROUP_PREFIX = "MarkdownPlusListRenumber_"

describe("markdown-plus list autocmds", function()
  local buf

  ---Fetch the registered callback for a given event in the buffer's augroup.
  ---@param target_buf integer
  ---@param event string
  ---@return function|nil
  local function callback_for(target_buf, event)
    local group = AUGROUP_PREFIX .. target_buf
    for _, cmd in ipairs(vim.api.nvim_get_autocmds({ group = group, event = event })) do
      if cmd.callback then
        return cmd.callback
      end
    end
    return nil
  end

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
  end)

  after_each(function()
    -- Stops any pending timers and removes all renumber augroups.
    autocmds.teardown()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("has_ordered_list_near_row", function()
    it("returns true when an ordered list is near the row", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. First", "2. Second" })
      assert.is_true(autocmds.has_ordered_list_near_row(buf, 1))
    end)

    it("detects all orderable list types", function()
      local cases = { "1. a", "1) a", "a. x", "A. x", "a) x", "A) x" }
      for _, line in ipairs(cases) do
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        assert.is_true(autocmds.has_ordered_list_near_row(buf, 1), "expected orderable: " .. line)
      end
    end)

    it("returns false for unordered lists", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item", "* item", "+ item" })
      assert.is_false(autocmds.has_ordered_list_near_row(buf, 1))
    end)

    it("returns false for plain text", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "just text", "more text" })
      assert.is_false(autocmds.has_ordered_list_near_row(buf, 1))
    end)

    it("respects the lookaround window", function()
      local lines = {}
      for i = 1, 60 do
        lines[i] = "plain text"
      end
      lines[1] = "1. ordered far away"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      -- Ordered list at row 1 is >20 lines from row 50 -> not detected.
      assert.is_false(autocmds.has_ordered_list_near_row(buf, 50))
      -- Row 10 is within the lookaround window of row 1 -> detected.
      assert.is_true(autocmds.has_ordered_list_near_row(buf, 10))
    end)
  end)

  describe("get_cursor_row_for_buffer", function()
    it("returns the cursor row for the current buffer", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.equals(2, autocmds.get_cursor_row_for_buffer(buf))
    end)

    it("returns a valid row for a non-current buffer", function()
      local other = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(other, 0, -1, false, { "x", "y" })

      local row = autocmds.get_cursor_row_for_buffer(other)
      assert.is_number(row)
      assert.is_true(row >= 1)

      vim.api.nvim_buf_delete(other, { force = true })
    end)
  end)

  describe("stop_debounce_timer", function()
    it("is a no-op when no timer is registered", function()
      assert.is_nil(autocmds.renumber_timers[buf])
      assert.has_no.errors(function()
        autocmds.stop_debounce_timer(buf)
      end)
      assert.is_nil(autocmds.renumber_timers[buf])
    end)

    it("stops and clears an existing timer", function()
      local timer = vim.fn.timer_start(100000, function() end)
      autocmds.renumber_timers[buf] = timer

      autocmds.stop_debounce_timer(buf)

      assert.is_nil(autocmds.renumber_timers[buf])
    end)
  end)

  describe("setup_renumber_autocmds", function()
    it("registers TextChanged, TextChangedI, and buffer-delete autocmds", function()
      autocmds.setup_renumber_autocmds()

      local registered = vim.api.nvim_get_autocmds({ group = AUGROUP_PREFIX .. buf })
      local events = {}
      for _, cmd in ipairs(registered) do
        events[cmd.event] = true
      end

      assert.is_true(events.TextChanged)
      assert.is_true(events.TextChangedI)
      assert.is_true(events.BufDelete or events.BufWipeout)
    end)

    it("renumbers immediately on normal-mode TextChanged near an ordered list", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "1. c" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      autocmds.setup_renumber_autocmds()

      local cb = callback_for(buf, "TextChanged")
      assert.is_function(cb)
      cb({ buf = buf })

      assert.same({ "1. a", "2. b", "3. c" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("skips renumber on TextChanged when no ordered list is near", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- a", "- b" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      autocmds.setup_renumber_autocmds()

      local cb = callback_for(buf, "TextChanged")
      cb({ buf = buf })

      assert.same({ "- a", "- b" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("does not renumber a non-modifiable buffer on TextChanged", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      autocmds.setup_renumber_autocmds()

      local cb = callback_for(buf, "TextChanged")
      vim.bo[buf].modifiable = false
      cb({ buf = buf })

      vim.bo[buf].modifiable = true
      assert.same({ "1. a", "1. b" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("registers a debounce timer on insert-mode TextChangedI near an ordered list", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      autocmds.setup_renumber_autocmds()

      local cb = callback_for(buf, "TextChangedI")
      assert.is_function(cb)

      cb({ buf = buf })
      assert.is_not_nil(autocmds.renumber_timers[buf])

      -- A second edit restarts the debounce timer without erroring.
      cb({ buf = buf })
      assert.is_not_nil(autocmds.renumber_timers[buf])

      autocmds.stop_debounce_timer(buf)
    end)

    it("does not register a debounce timer when no ordered list is near", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- a", "- b" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      autocmds.setup_renumber_autocmds()

      local cb = callback_for(buf, "TextChangedI")
      cb({ buf = buf })

      assert.is_nil(autocmds.renumber_timers[buf])
    end)

    it("clears the debounce timer when the buffer is deleted", function()
      autocmds.setup_renumber_autocmds()
      autocmds.renumber_timers[buf] = vim.fn.timer_start(100000, function() end)

      local cb = callback_for(buf, "BufDelete") or callback_for(buf, "BufWipeout")
      assert.is_function(cb)
      cb({ buf = buf })

      assert.is_nil(autocmds.renumber_timers[buf])
    end)
  end)

  describe("teardown", function()
    it("stops and clears all debounce timers", function()
      autocmds.renumber_timers[101] = vim.fn.timer_start(100000, function() end)
      autocmds.renumber_timers[102] = vim.fn.timer_start(100000, function() end)

      autocmds.teardown()

      assert.is_nil(autocmds.renumber_timers[101])
      assert.is_nil(autocmds.renumber_timers[102])
    end)

    it("removes renumber augroups for multiple buffers", function()
      autocmds.setup_renumber_autocmds()

      local buf2 = vim.api.nvim_create_buf(false, true)
      vim.bo[buf2].filetype = "markdown"
      vim.api.nvim_set_current_buf(buf2)
      autocmds.setup_renumber_autocmds()

      autocmds.teardown()

      -- Querying a removed augroup raises, so pcall should fail for both.
      assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = AUGROUP_PREFIX .. buf }))
      assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = AUGROUP_PREFIX .. buf2 }))

      vim.api.nvim_buf_delete(buf2, { force = true })
    end)
  end)
end)
