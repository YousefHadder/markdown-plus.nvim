local markdown_plus = require("markdown-plus")
local insert_mode = require("spec.helpers.insert_mode")

describe("configured filetype lifecycle", function()
  local buffers
  local original_localleader
  local original_schedule
  local saved_global_enter

  ---@param filetype string
  ---@param lines? string[]
  ---@return integer
  local function new_buffer(filetype, lines)
    local buf = vim.api.nvim_create_buf(false, true)
    buffers[#buffers + 1] = buf
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "- item" })
    vim.bo.filetype = filetype
    vim.bo.autoindent = false
    vim.bo.formatoptions = ""
    vim.bo.indentexpr = ""
    return buf
  end

  ---@param buf integer
  ---@param lhs string
  ---@param mode string
  ---@return table
  local function mapping(buf, lhs, mode)
    return vim.api.nvim_buf_call(buf, function()
      return vim.fn.maparg(lhs, mode, false, true)
    end)
  end

  ---@param buf integer
  ---@return string[]
  local function lines(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  ---@param buf integer
  ---@return string[]
  local function press_enter(buf)
    vim.api.nvim_set_current_buf(buf)
    return insert_mode.press_normal("A<CR>", 1, 0).lines
  end

  ---@param buf integer
  ---@return nil
  local function assert_no_defaults(buf)
    for _, mode in ipairs({ "n", "i", "x", "s" }) do
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
        assert.is_nil(map.rhs and map.rhs:match("^<Plug>%(MarkdownPlus"), mode .. ": " .. map.lhs)
      end
    end
  end

  ---@param buf integer
  ---@return table[]
  local function edit_autocmds(buf)
    return vim.api.nvim_get_autocmds({ buffer = buf, event = { "TextChanged", "TextChangedI" } })
  end

  before_each(function()
    markdown_plus.teardown()
    buffers = {}
    saved_global_enter = nil
    original_localleader = vim.g.maplocalleader
    original_schedule = vim.schedule
    vim.g.maplocalleader = ","
  end)

  after_each(function()
    vim.schedule = original_schedule
    markdown_plus.teardown()
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    if saved_global_enter then
      vim.keymap.del("i", "<CR>")
      if next(saved_global_enter) then
        vim.fn.mapset("i", false, saved_global_enter)
      end
    end
    vim.g.maplocalleader = original_localleader
  end)

  it("leaves initially unsupported buffers untouched", function()
    markdown_plus.setup({})
    local buf = new_buffer("lua")

    assert_no_defaults(buf)
    assert.are.same({}, vim.api.nvim_buf_get_commands(buf, {}))
    assert.are.same({}, edit_autocmds(buf))
    assert.are.same({ "- item", "" }, press_enter(buf))
  end)

  it("releases owned mappings, commands, tracking, and edit autocmds on exit", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown")
    assert.are.equal("<Plug>(MarkdownPlusListEnter)", mapping(buf, "<CR>", "i").rhs)
    assert.is_not_nil(vim.api.nvim_buf_get_commands(buf, {}).Toc)
    assert.are.equal(2, #edit_autocmds(buf))

    vim.bo[buf].filetype = "lua"

    assert_no_defaults(buf)
    assert.are.same({}, vim.api.nvim_buf_get_commands(buf, {}))
    assert.are.same({}, edit_autocmds(buf))
    assert.is_false(pcall(vim.api.nvim_buf_get_var, buf, "markdown_plus_default_keymaps"))
    assert.are.same({ "- item", "" }, press_enter(buf))
  end)

  it("restores editing and owned state on repeated exit and re-entry", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown")

    for _, filetype in ipairs({ "lua", "markdown", "lua", "markdown" }) do
      vim.bo[buf].filetype = filetype
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
      if filetype == "markdown" then
        assert.are.equal("<Plug>(MarkdownPlusListEnter)", mapping(buf, "<CR>", "i").rhs)
        assert.is_not_nil(vim.api.nvim_buf_get_commands(buf, {}).Toc)
        assert.are.equal(2, #edit_autocmds(buf))
        assert.are.same({ "- item", "- " }, press_enter(buf))
      else
        assert.are.same({ "- item", "" }, press_enter(buf))
      end
    end
  end)

  it("releases state when the filetype is cleared and reactivates from an empty filetype", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown")

    vim.bo[buf].filetype = ""

    assert_no_defaults(buf)
    assert.are.same({}, vim.api.nvim_buf_get_commands(buf, {}))
    assert.are.same({}, edit_autocmds(buf))
    assert.are.same({ "- item", "" }, press_enter(buf))

    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
    assert.are.same({ "- item", "- " }, press_enter(buf))
  end)

  it("honors custom-only filetypes and transitions between configured types", function()
    markdown_plus.setup({ filetypes = { "note", "text" } })
    local buf = new_buffer("markdown")
    assert.are.same({ "- item", "" }, press_enter(buf))

    for _, filetype in ipairs({ "note", "text", "lua", "note" }) do
      vim.bo[buf].filetype = filetype
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
      local expected = filetype == "lua" and { "- item", "" } or { "- item", "- " }
      assert.are.same(expected, press_enter(buf))
    end
  end)

  it("tracks transitions for a custom-filetype buffer already open at setup", function()
    local buf = new_buffer("note")
    markdown_plus.setup({ filetypes = { "note" } })
    assert.are.same({ "- item", "- " }, press_enter(buf))

    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
    assert_no_defaults(buf)
    assert.are.same({ "- item", "" }, press_enter(buf))

    vim.bo[buf].filetype = "note"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
    assert.are.same({ "- item", "- " }, press_enter(buf))
  end)

  it("cleans and restores non-keymap state when default keymaps are disabled", function()
    markdown_plus.setup({ keymaps = { enabled = false } })
    local buf = new_buffer("markdown")
    assert_no_defaults(buf)
    assert.is_not_nil(vim.api.nvim_buf_get_commands(buf, {}).Toc)

    vim.bo[buf].filetype = "lua"
    assert.are.same({}, vim.api.nvim_buf_get_commands(buf, {}))
    assert.are.same({}, edit_autocmds(buf))

    vim.bo[buf].filetype = "markdown"
    assert_no_defaults(buf)
    assert.is_not_nil(vim.api.nvim_buf_get_commands(buf, {}).Toc)
    assert.are.equal(2, #edit_autocmds(buf))
  end)

  it("keeps disabled features and modules disabled on re-entry", function()
    markdown_plus.setup({
      features = { list_management = false, headers_toc = false, footnotes = false },
      code_block = { enabled = false },
      table = { enabled = false },
    })
    local buf = new_buffer("markdown")
    vim.bo[buf].filetype = "lua"
    vim.bo[buf].filetype = "markdown"

    assert.is_nil(mapping(buf, "<CR>", "i").rhs)
    assert.is_nil(mapping(buf, "]b", "n").rhs)
    assert.is_nil(mapping(buf, ",tf", "n").rhs)
    assert.are.same({}, vim.api.nvim_buf_get_commands(buf, {}))
    assert.are.same({}, edit_autocmds(buf))
    assert.are.equal("<Plug>(MarkdownPlusBold)", mapping(buf, ",mb", "n").rhs)
  end)

  it("preserves pre-existing buffer mappings and personal Plug mappings", function()
    markdown_plus.setup({})
    local buf = new_buffer("lua")
    vim.keymap.set("i", "<CR>", "FOREIGN", { buffer = buf })
    vim.keymap.set("n", ",mb", "<Plug>(MarkdownPlusBold)", { buffer = buf, desc = "Personal bold" })
    local enter = mapping(buf, "<CR>", "i")
    local bold = mapping(buf, ",mb", "n")

    for _, filetype in ipairs({ "markdown", "lua", "markdown", "lua" }) do
      vim.bo[buf].filetype = filetype
      assert.are.same(enter, mapping(buf, "<CR>", "i"))
      assert.are.same(bold, mapping(buf, ",mb", "n"))
    end
    assert.are.same({ "- itemFOREIGN" }, press_enter(buf))
  end)

  it("preserves replacement callbacks even with an owned default's description", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown")
    local calls = 0
    local replacement = function()
      calls = calls + 1
      return "FOREIGN"
    end
    vim.keymap.set("i", "<CR>", replacement, {
      buffer = buf,
      expr = true,
      desc = mapping(buf, "<CR>", "i").desc,
    })
    vim.keymap.set("n", ",mb", "<Plug>(MarkdownPlusBold)", { buffer = buf, desc = "Personal bold" })

    for _, filetype in ipairs({ "lua", "markdown", "lua" }) do
      vim.bo[buf].filetype = filetype
      assert.are.equal(replacement, mapping(buf, "<CR>", "i").callback)
      assert.are.equal("Personal bold", mapping(buf, ",mb", "n").desc)
    end
    assert.are.same({ "- itemFOREIGN" }, press_enter(buf))
    assert.are.equal(1, calls)
  end)

  it("reveals foreign global mappings on exit and shadows them again on re-entry", function()
    saved_global_enter = vim.fn.maparg("<CR>", "i", false, true)
    vim.keymap.set("i", "<CR>", "GLOBAL")
    markdown_plus.setup({})
    local buf = new_buffer("markdown")
    assert.are.equal("<Plug>(MarkdownPlusListEnter)", mapping(buf, "<CR>", "i").rhs)

    vim.bo[buf].filetype = "lua"
    assert.are.equal(0, mapping(buf, "<CR>", "i").buffer)
    assert.are.same({ "- itemGLOBAL" }, press_enter(buf))

    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
    assert.are.same({ "- item", "- " }, press_enter(buf))
  end)

  it("preserves pre-existing and replacement TOC commands through transitions", function()
    markdown_plus.setup({})
    local buf = new_buffer("lua")
    local calls = { toc = 0, toch = 0 }
    vim.api.nvim_buf_create_user_command(buf, "Toc", function()
      calls.toc = calls.toc + 1
    end, {})
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_create_user_command(buf, "Toch", function()
      calls.toch = calls.toch + 1
    end, { desc = vim.api.nvim_buf_get_commands(buf, {}).Toch.desc })

    for _, filetype in ipairs({ "lua", "markdown", "lua" }) do
      vim.bo[buf].filetype = filetype
      vim.cmd("Toc")
      vim.cmd("Toch")
      if filetype == "lua" then
        assert.is_nil(vim.api.nvim_buf_get_commands(buf, {}).Toct)
      end
    end
    assert.are.same({ toc = 3, toch = 3 }, calls)
  end)

  it("preserves foreign buffer variables and edit autocommands", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown")
    vim.b[buf].foreign_state = { active = true }
    local calls = 0
    local autocmd = vim.api.nvim_create_autocmd("TextChanged", {
      buffer = buf,
      callback = function()
        calls = calls + 1
      end,
    })

    for _, filetype in ipairs({ "lua", "text", "markdown", "lua" }) do
      vim.bo[buf].filetype = filetype
      assert.are.same({ active = true }, vim.b[buf].foreign_state)
      vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    end

    assert.are.equal(4, calls)
    assert.are.equal(autocmd, edit_autocmds(buf)[1].id)
  end)

  it("leaves other buffers and global Plug handlers active when a hidden buffer exits", function()
    markdown_plus.setup({})
    local first = new_buffer("markdown")
    local second = new_buffer("markdown")
    local enter = mapping(second, "<CR>", "i")
    local commands = vim.api.nvim_buf_get_commands(second, {})
    local autocmds = edit_autocmds(second)
    local plug = vim.fn.maparg("<Plug>(MarkdownPlusListEnter)", "i", false, true)

    vim.bo[first].filetype = "lua"

    assert.are.equal(second, vim.api.nvim_get_current_buf())
    assert_no_defaults(first)
    assert.are.same(enter, mapping(second, "<CR>", "i"))
    assert.are.same(commands, vim.api.nvim_buf_get_commands(second, {}))
    assert.are.same(autocmds, edit_autocmds(second))
    assert.are.same(plug, vim.fn.maparg("<Plug>(MarkdownPlusListEnter)", "i", false, true))
    assert.are.same({ "- item", "- " }, press_enter(second))

    vim.bo[first].filetype = "markdown"
    assert.are.equal(second, vim.api.nvim_get_current_buf())
    assert.are.equal("<Plug>(MarkdownPlusListEnter)", mapping(first, "<CR>", "i").rhs)
  end)

  it("stops the exited buffer's pending renumbering without cancelling another buffer's timer", function()
    markdown_plus.setup({})
    local first = new_buffer("markdown", { "1. first", "1. unchanged" })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = first })
    local second = new_buffer("markdown", { "1. second", "1. renumbered" })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = second })

    vim.bo[first].filetype = "lua"

    assert.is_true(vim.wait(1000, function()
      return lines(second)[2] == "2. renumbered"
    end, 10))
    assert.are.same({ "1. first", "1. unchanged" }, lines(first))
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = first })
    assert.are.same({ "1. first", "1. unchanged" }, lines(first))
  end)

  it("invalidates renumbering already queued on the scheduler before exit", function()
    markdown_plus.setup({})
    local buf = new_buffer("markdown", { "1. first", "1. unchanged" })
    local queued = {}
    vim.schedule = function(callback)
      queued[#queued + 1] = callback
    end
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })
    assert.is_true(vim.wait(1000, function()
      return #queued > 0
    end, 10))
    vim.schedule = original_schedule

    vim.bo[buf].filetype = "lua"
    for _, callback in ipairs(queued) do
      callback()
    end

    assert.are.same({ "1. first", "1. unchanged" }, lines(buf))
  end)
end)
