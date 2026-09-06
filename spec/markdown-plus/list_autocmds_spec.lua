---Test suite for markdown-plus.nvim list auto-renumber autocommands
---Tests the extracted autocmds sub-module: helpers, autocommand registration,
---callback behavior, and teardown of timers and augroups.
---@diagnostic disable: undefined-field
local autocmds = require("markdown-plus.list.autocmds")

local AUGROUP_PREFIX = "MarkdownPlusListRenumber_"

describe("automatic renumber undo ownership", function()
  local buf
  local timers, scheduled
  local timer_start, timer_stop, schedule
  local extra_buffers

  ---@return nil
  local function sync()
    vim.bo.undolevels = vim.bo.undolevels
  end

  ---@param event string
  ---@return nil
  local function emit(event)
    vim.api.nvim_exec_autocmds(event, { buffer = buf })
  end

  ---@return string[]
  local function lines()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  ---@return nil
  local function edit_list()
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "1. edited" })
    sync()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
  end

  ---@return nil
  local function edit_paragraph()
    vim.api.nvim_buf_set_lines(buf, 49, 50, false, { "unrelated edit" })
    sync()
    vim.api.nvim_win_set_cursor(0, { 50, 0 })
  end

  ---Run even stopped timers, modeling an already delivered callback.
  ---@return nil
  local function drain()
    for _, timer in ipairs(timers) do
      timer()
    end
    timers = {}
    local callbacks = scheduled
    scheduled = {}
    for _, callback in ipairs(callbacks) do
      callback()
    end
  end

  before_each(function()
    autocmds.teardown()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo.filetype = "markdown"
    local seed = { "1. one", "1. two", "1. three" }
    for _ = 4, 50 do
      seed[#seed + 1] = ""
    end
    seed[50] = "paragraph"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, seed)
    sync()
    timers, scheduled, extra_buffers = {}, {}, {}
    timer_start, timer_stop, schedule = vim.fn.timer_start, vim.fn.timer_stop, vim.schedule
    vim.fn.timer_start = function(_, callback)
      timers[#timers + 1] = callback
      return #timers
    end
    vim.fn.timer_stop = function() end
    vim.schedule = function(callback)
      scheduled[#scheduled + 1] = callback
    end
    autocmds.setup_renumber_autocmds()
  end)

  after_each(function()
    autocmds.teardown()
    vim.fn.timer_start, vim.fn.timer_stop, vim.schedule = timer_start, timer_stop, schedule
    for _, extra in ipairs(extra_buffers) do
      vim.api.nvim_buf_delete(extra, { force = true })
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  for _, event in ipairs({ "TextChanged", "TextChangedI" }) do
    it("leaves no pending join after a no-op " .. event .. " callback", function()
      vim.api.nvim_buf_set_lines(buf, 0, 3, false, { "1. one", "2. two", "3. three" })
      sync()
      vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "2. edited" })
      sync()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      emit(event)
      drain()
      vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "2. next edit" })
      vim.cmd("silent undo")
      assert.are.equal("2. edited", lines()[2])
    end)

    it("joins the real " .. event .. " renumber to its triggering edit", function()
      edit_list()
      local sequence = vim.fn.undotree().seq_cur
      emit(event)
      drain()
      assert.are.same({ "1. one", "2. edited", "3. three" }, { lines()[1], lines()[2], lines()[3] })
      assert.are.equal(sequence, vim.fn.undotree().seq_cur)
      vim.cmd("silent undo")
      emit("TextChanged")
      drain()
      assert.are.same({ "1. one", "1. two", "1. three" }, { lines()[1], lines()[2], lines()[3] })
      vim.cmd("silent redo")
      assert.are.same({ "1. one", "2. edited", "3. three" }, { lines()[1], lines()[2], lines()[3] })
    end)

    it("invalidates pending work on a distant " .. event .. " edit", function()
      edit_list()
      emit("TextChangedI")
      edit_paragraph()
      emit(event)
      drain()
      assert.are.equal("1. edited", lines()[2])
      vim.cmd("silent undo")
      assert.are.equal("paragraph", lines()[50])
      assert.are.equal("1. edited", lines()[2])
      vim.cmd("silent undo")
      assert.are.equal("1. two", lines()[2])
    end)
  end

  it("rejects an intervening edit even before its TextChanged event is delivered", function()
    edit_list()
    emit("TextChangedI")
    edit_paragraph()
    drain()
    assert.are.equal("1. edited", lines()[2])
    vim.cmd("silent undo")
    assert.are.equal("paragraph", lines()[50])
    assert.are.equal("1. edited", lines()[2])
  end)

  it("rejects a timer owned by an undone edit after an unrelated new branch", function()
    edit_list()
    emit("TextChangedI")
    vim.cmd("silent undo")
    edit_paragraph()
    assert.is_true(autocmds.is_at_undo_tip(buf))
    drain()
    assert.are.equal("1. two", lines()[2])
    vim.cmd("silent undo")
    assert.are.equal("paragraph", lines()[50])
    assert.are.equal("1. two", lines()[2])
  end)

  it("rejects work after undo and redo even when the original sequence is restored", function()
    edit_list()
    local sequence = vim.fn.undotree().seq_cur
    emit("TextChangedI")
    vim.cmd("silent undo")
    vim.cmd("silent redo")
    assert.are.equal(sequence, vim.fn.undotree().seq_cur)
    drain()
    assert.are.equal("1. edited", lines()[2])
  end)

  it("rejects an intervening write joined into the same undo sequence", function()
    edit_list()
    local sequence = vim.fn.undotree().seq_cur
    emit("TextChangedI")
    vim.cmd("undojoin")
    edit_paragraph()
    assert.are.equal(sequence, vim.fn.undotree().seq_cur)
    drain()
    assert.are.equal("1. edited", lines()[2])
  end)

  it("consumes only the newest request when old timers and scheduled callbacks arrive late", function()
    edit_list()
    emit("TextChangedI")
    local old_timer = timers[1]
    old_timer()
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "1. newer edit" })
    sync()
    local sequence = vim.fn.undotree().seq_cur
    emit("TextChangedI")
    local new_timer_id = autocmds.renumber_timers[buf]
    old_timer()
    assert.are.equal(new_timer_id, autocmds.renumber_timers[buf])
    drain()
    assert.are.equal("2. newer edit", lines()[2])
    assert.are.equal(sequence, vim.fn.undotree().seq_cur)
    vim.cmd("silent undo")
    assert.are.equal("1. edited", lines()[2])
  end)

  it("rejects already scheduled work after an unrelated edit", function()
    edit_list()
    emit("TextChangedI")
    timers[1]()
    timers = {}
    edit_paragraph()
    emit("TextChanged")
    drain()
    assert.are.equal("1. edited", lines()[2])
  end)

  it("invalidates already scheduled work on teardown", function()
    edit_list()
    emit("TextChangedI")
    timers[1]()
    timers = {}
    autocmds.teardown()
    drain()
    assert.are.equal("1. edited", lines()[2])
  end)

  it("invalidates already scheduled work when autocmds are reinstalled", function()
    edit_list()
    emit("TextChangedI")
    timers[1]()
    timers = {}
    autocmds.setup_renumber_autocmds()
    drain()
    assert.are.equal("1. edited", lines()[2])
  end)

  it("preserves undo ownership through a real timer and scheduled callback", function()
    vim.fn.timer_start, vim.fn.timer_stop, vim.schedule = timer_start, timer_stop, schedule
    edit_list()
    local sequence = vim.fn.undotree().seq_cur
    emit("TextChangedI")
    assert.is_true(vim.wait(1000, function()
      return lines()[2] == "2. edited"
    end, 10))
    assert.are.equal(sequence, vim.fn.undotree().seq_cur)
    vim.cmd("silent undo")
    assert.are.equal("1. two", lines()[2])
  end)

  it("renumbers the owning buffer without joining into the newly current buffer", function()
    edit_list()
    local owner_sequence = vim.fn.undotree().seq_cur
    emit("TextChangedI")
    local other = vim.api.nvim_create_buf(false, true)
    extra_buffers[#extra_buffers + 1] = other
    vim.api.nvim_set_current_buf(other)
    vim.api.nvim_buf_set_lines(other, 0, -1, false, { "other" })
    sync()
    vim.api.nvim_buf_set_lines(other, 0, -1, false, { "other edited" })
    sync()
    local other_sequence = vim.fn.undotree().seq_cur
    drain()
    assert.are.equal(other, vim.api.nvim_get_current_buf())
    assert.are.equal(other_sequence, vim.fn.undotree().seq_cur)
    assert.are.equal("2. edited", lines()[2])
    vim.cmd("silent undo")
    assert.are.same({ "other" }, vim.api.nvim_buf_get_lines(other, 0, -1, false))
    vim.api.nvim_set_current_buf(buf)
    assert.are.equal(owner_sequence, vim.fn.undotree().seq_cur)
    vim.cmd("silent undo")
    assert.are.equal("1. two", lines()[2])
  end)

  it("does not revive work after its buffer is deleted", function()
    edit_list()
    emit("TextChangedI")
    timers[1]()
    timers = {}
    vim.api.nvim_buf_delete(buf, { force = true })
    assert.has_no.errors(drain)
  end)
end)

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
