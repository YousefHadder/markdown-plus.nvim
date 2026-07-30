---Test suite for markdown-plus.nvim list normal_handler
---Tests backspace, normal-o, and normal-O handlers
---@diagnostic disable: undefined-field
local normal_handler = require("markdown-plus.list.normal_handler")
local list = require("markdown-plus.list")
local insert_mode = require("spec.helpers.insert_mode")

-- `<Plug>` names the production `o`/`O` defaults forward to (see `list/keymaps.lua`).
local O_PLUG_BELOW = "<Plug>(MarkdownPlusNewListItemBelow)"
local O_PLUG_ABOVE = "<Plug>(MarkdownPlusNewListItemAbove)"

describe("markdown-plus list normal_handler", function()
  before_each(function()
    require("markdown-plus.keymap_fallback").reset()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    -- Setup list module so parser works
    list.setup({
      enabled = true,
      features = { list_management = true },
      list = {
        smart_outdent = false,
        auto_renumber = true,
        html_block_awareness = true,
      },
    })
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("handle_backspace", function()
    -- Outside list context the handler no longer reimplements deletion; it defers to
    -- `keymap_fallback`, which queues keys. These cases therefore drive a real insert-mode
    -- session so the queued keys are flushed and their effect is observable.
    after_each(function()
      insert_mode.unmap_backspace_default()
    end)

    it("on non-list line deletes char", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
      insert_mode.map_backspace_default(normal_handler.handle_backspace)
      local result = insert_mode.backspace(1, 5)
      assert.are.equal("hell", result.lines[1])
    end)

    it("at start of non-list line joins with previous", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
      insert_mode.map_backspace_default(normal_handler.handle_backspace)
      local result = insert_mode.backspace(2, 0)
      assert.are.equal(1, #result.lines)
      assert.are.equal("firstsecond", result.lines[1])
    end)

    it("removes list marker", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal("item", line)
    end)
  end)

  describe("handle_backspace fallback to foreign mappings", function()
    -- Simulates a mini.pairs-style global insert-mode `<BS>` mapping installed before
    -- markdown-plus shadows `<BS>` with its buffer-local default.
    local fired

    before_each(function()
      fired = false
      vim.keymap.set("i", "<BS>", function()
        fired = true
        return "<BS>"
      end, { expr = true, replace_keycodes = true })
    end)

    after_each(function()
      pcall(vim.keymap.del, "i", "<BS>")
    end)

    it("invokes the foreign mapping when the cursor is not in a list", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
    end)

    it("invokes the foreign mapping inside list item content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item text" })
      vim.api.nvim_win_set_cursor(0, { 1, 8 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
    end)

    it("removes the list marker without invoking the foreign mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      assert.are.equal("item", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      assert.is_false(fired)
    end)

    it("empties an empty list item marker without invoking the foreign mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- " })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      normal_handler.handle_backspace()
      assert.are.equal("", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
      assert.is_false(fired)
    end)

    it("ignores our own buffer-local default when resolving the fallback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      vim.keymap.set("i", "<BS>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      normal_handler.handle_backspace()
      assert.is_true(fired)
    end)
  end)

  describe("handle_normal_o", function()
    it("on list item creates next item", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_o()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("- ", lines[2])
    end)

    it("on ordered list increments", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1. first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_o()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.is_truthy(lines[2]:match("^2%. "))
    end)

    it("on non-list inserts blank line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      insert_mode.map_default("n", "o", O_PLUG_BELOW, normal_handler.handle_normal_o)
      local result = insert_mode.press_normal("o", 1, 0)
      insert_mode.unmap_default("n", "o", O_PLUG_BELOW)
      assert.are.equal(2, #result.lines)
      assert.are.equal("", result.lines[2])
    end)
  end)

  describe("handle_normal_O", function()
    it("on list item creates prev item", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      normal_handler.handle_normal_O()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("- ", lines[1])
    end)
  end)

  -- Outside list context `o`/`O` defer to `keymap_fallback` instead of hand-rolling the open:
  -- that preserves counts, 'autoindent', 'formatoptions' comment continuation, and any user
  -- normal-mode `o`/`O` mapping. Inside a list, marker continuation still wins.
  describe("normal-mode open-line fallback", function()
    ---Install our buffer-local default and a *foreign* global mapping for the same key
    ---@param key string "o" or "O"
    ---@param plug string `<Plug>` name our default forwards to
    ---@param handler fun() Our handler
    ---@param state table Mutable state; `state.foreign` counts invocations, `state.count`
    ---records the `v:count1` the foreign mapping observed
    ---@return nil
    local function install(key, plug, handler, state)
      insert_mode.map_default("n", key, plug, handler)
      vim.keymap.set("n", key, function()
        state.foreign = state.foreign + 1
        state.count = vim.v.count1
      end, { silent = true })
    end

    -- Safety net: `press_normal` drives a real key burst, so an error mid-test would skip the
    -- per-test `uninstall` and leak a global `o`/`O` mapping into every later spec in this
    -- Neovim instance. Deleting unconditionally here is harmless when already removed.
    after_each(function()
      pcall(vim.keymap.del, "n", "o")
      pcall(vim.keymap.del, "n", "O")
    end)

    ---Remove the mappings installed by `install`
    ---@param key string "o" or "O"
    ---@param plug string `<Plug>` name used with `install`
    ---@return nil
    local function uninstall(key, plug)
      pcall(vim.keymap.del, "n", key)
      insert_mode.unmap_default("n", key, plug)
    end

    it("runs a foreign global `o` mapping on a non-list line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      local state = { foreign = 0 }
      install("o", O_PLUG_BELOW, normal_handler.handle_normal_o, state)

      insert_mode.press_normal("o", 1, 0)
      uninstall("o", O_PLUG_BELOW)

      assert.are.equal(1, state.foreign)
    end)

    it("does not run a foreign `o` mapping on a list line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      local state = { foreign = 0 }
      install("o", O_PLUG_BELOW, normal_handler.handle_normal_o, state)

      local result = insert_mode.press_normal("o", 1, 0)
      uninstall("o", O_PLUG_BELOW)

      assert.are.equal(0, state.foreign)
      assert.are.equal("- ", result.lines[2])
    end)

    it("runs a foreign global `O` mapping on a non-list line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      local state = { foreign = 0 }
      install("O", O_PLUG_ABOVE, normal_handler.handle_normal_O, state)

      insert_mode.press_normal("O", 1, 0)
      uninstall("O", O_PLUG_ABOVE)

      assert.are.equal(1, state.foreign)
    end)

    it("does not run a foreign `O` mapping on a list line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- first" })
      local state = { foreign = 0 }
      install("O", O_PLUG_ABOVE, normal_handler.handle_normal_O, state)

      local result = insert_mode.press_normal("O", 1, 0)
      uninstall("O", O_PLUG_ABOVE)

      assert.are.equal(0, state.foreign)
      assert.are.equal("- ", result.lines[1])
    end)

    it("falls back to native `o` when no foreign mapping exists", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      insert_mode.map_default("n", "o", O_PLUG_BELOW, normal_handler.handle_normal_o)

      local result = insert_mode.press_normal("o", 1, 0)
      insert_mode.unmap_default("n", "o", O_PLUG_BELOW)

      assert.are.equal(2, #result.lines)
      assert.are.equal("plain text", result.lines[1])
      assert.are.equal("", result.lines[2])
      assert.are.equal(2, result.cursor[1])
    end)

    it("falls back to native `O` when no foreign mapping exists", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      insert_mode.map_default("n", "O", O_PLUG_ABOVE, normal_handler.handle_normal_O)

      local result = insert_mode.press_normal("O", 1, 0)
      insert_mode.unmap_default("n", "O", O_PLUG_ABOVE)

      assert.are.equal(2, #result.lines)
      assert.are.equal("", result.lines[1])
      assert.are.equal("plain text", result.lines[2])
      assert.are.equal(1, result.cursor[1])
    end)

    -- The hand-rolled open this replaced inserted a literal empty line, which silently
    -- dropped `'autoindent'`. Deferring to the real `o` restores it.
    it("preserves 'autoindent' on the native `o` fallback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "    plain text" })
      local saved_autoindent = vim.bo.autoindent
      vim.bo.autoindent = true
      insert_mode.map_default("n", "o", O_PLUG_BELOW, normal_handler.handle_normal_o)

      local result = insert_mode.press_normal("ox", 1, 4)
      insert_mode.unmap_default("n", "o", O_PLUG_BELOW)
      vim.bo.autoindent = saved_autoindent

      assert.are.equal("    x", result.lines[2])
    end)

    -- A count is applied by `o`/`O` only when insert mode is left, so these assert on the
    -- buffer *after* `press_normal`'s trailing `<Esc>` rather than on its mid-insert capture.

    it("applies a count on the native `o` fallback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      insert_mode.map_default("n", "o", O_PLUG_BELOW, normal_handler.handle_normal_o)

      insert_mode.press_normal("3ox", 1, 0)
      insert_mode.unmap_default("n", "o", O_PLUG_BELOW)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "plain text", "x", "x", "x" }, lines)
    end)

    it("applies a count on the native `O` fallback", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      insert_mode.map_default("n", "O", O_PLUG_ABOVE, normal_handler.handle_normal_O)

      insert_mode.press_normal("3Ox", 1, 0)
      insert_mode.unmap_default("n", "O", O_PLUG_ABOVE)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.same({ "x", "x", "x", "plain text" }, lines)
    end)

    -- Foreign targets are invoked synchronously from inside our own mapping, where `v:count`
    -- is still the one the user typed, so they read it themselves and must NOT be prefixed.
    it("leaves the count readable by a foreign `o` mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      local state = { foreign = 0 }
      install("o", O_PLUG_BELOW, normal_handler.handle_normal_o, state)

      insert_mode.press_normal("3o", 1, 0)
      uninstall("o", O_PLUG_BELOW)

      assert.are.equal(1, state.foreign)
      assert.are.equal(3, state.count)
    end)

    -- A foreign expr `o` map that returns `o` (the shape used by counter/notifier plugins) is
    -- the vanilla case where the pending count survives the mapping and applies to the returned
    -- key. Our mapping consumes the count, so the fallback has to re-prefix it.
    it("applies the count to keys returned by a foreign expr `o` mapping", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
      local state = { foreign = 0 }
      insert_mode.map_default("n", "o", O_PLUG_BELOW, normal_handler.handle_normal_o)
      vim.keymap.set("n", "o", function()
        state.foreign = state.foreign + 1
        return "o"
      end, { expr = true, silent = true })

      insert_mode.press_normal("3ox", 1, 0)
      uninstall("o", O_PLUG_BELOW)

      assert.are.equal(1, state.foreign)
      assert.are.same({ "plain text", "x", "x", "x" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)
end)
