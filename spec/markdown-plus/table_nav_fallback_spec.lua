---Insert-mode table navigation (`<A-h/j/k/l>`) keymap-fallback behavior.
---
---The navigation handlers own their keys only while the cursor is inside a table. Outside one,
---the key belongs to whoever else mapped it (window movers, terminal plugins, snippet engines),
---so the handler must yield through `keymap_fallback` instead of raw-feeding the arrow key.

local insert_mode = require("spec.helpers.insert_mode")

describe("table insert-mode navigation fallback", function()
  local keymaps = require("markdown-plus.table.keymaps")
  local buf

  ---Buffer-local defaults installed by `setup_buffer_keymaps`, paired with the key
  ---their fallback degrades to when nothing foreign is mapped.
  local NAV_KEYS = {
    { key = "<A-h>", native = "left" },
    { key = "<A-l>", native = "right" },
    { key = "<A-k>", native = "up" },
    { key = "<A-j>", native = "down" },
  }

  ---Counts of foreign-mapping invocations, keyed by lhs
  ---@type table<string, integer>
  local foreign_calls

  ---Install a foreign (non-markdown-plus) global insert-mode mapping for `lhs`
  ---@param lhs string
  ---@return nil
  local function map_foreign(lhs)
    vim.keymap.set("i", lhs, function()
      foreign_calls[lhs] = (foreign_calls[lhs] or 0) + 1
    end)
  end

  ---Number of times the foreign mapping for `lhs` fired
  ---@param lhs string
  ---@return integer
  local function calls(lhs)
    return foreign_calls[lhs] or 0
  end

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    buf = vim.api.nvim_get_current_buf()

    keymaps.register_plug_mappings()
    keymaps.setup_buffer_keymaps({
      enabled = true,
      auto_format = true,
      default_alignment = "left",
      confirm_destructive = true,
      keymaps = {
        enabled = true,
        prefix = "<localleader>t",
        insert_mode_navigation = true,
      },
    })

    foreign_calls = {}
    for _, nav in ipairs(NAV_KEYS) do
      map_foreign(nav.key)
    end
  end)

  after_each(function()
    for _, nav in ipairs(NAV_KEYS) do
      pcall(vim.keymap.del, "i", nav.key)
    end
    vim.cmd("bdelete!")
  end)

  describe("outside a table", function()
    it("runs the foreign mapping for every navigation key", function()
      for _, nav in ipairs(NAV_KEYS) do
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Regular text", "second line" })
        insert_mode.press(nav.key, 1, 4)
        assert.are.equal(1, calls(nav.key), nav.key .. " should defer to the foreign mapping")
      end
    end)

    it("leaves the buffer untouched when the foreign mapping runs", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Regular text" })
      local result = insert_mode.press("<A-l>", 1, 4)
      assert.are.same({ "Regular text" }, result.lines)
    end)
  end)

  describe("inside a table", function()
    before_each(function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "| A | B |",
        "| --- | --- |",
        "| 1 | 2 |",
      })
    end)

    -- Cell columns for the fixture below: column 0 starts at byte 2, column 1 at byte 6.
    it("navigates to the next cell without running the foreign mapping", function()
      local result = insert_mode.press("<A-l>", 1, 2)
      assert.are.equal(0, calls("<A-l>"))
      assert.are.same({ 1, 6 }, result.cursor)
    end)

    it("navigates to the previous cell without running the foreign mapping", function()
      local result = insert_mode.press("<A-h>", 1, 6)
      assert.are.equal(0, calls("<A-h>"))
      assert.are.same({ 1, 2 }, result.cursor)
    end)

    it("navigates to the cell below without running the foreign mapping", function()
      local result = insert_mode.press("<A-j>", 1, 2)
      assert.are.equal(0, calls("<A-j>"))
      assert.are.same({ 3, 2 }, result.cursor)
    end)

    it("navigates to the cell above without running the foreign mapping", function()
      local result = insert_mode.press("<A-k>", 3, 2)
      assert.are.equal(0, calls("<A-k>"))
      assert.are.same({ 1, 2 }, result.cursor)
    end)

    it("leaves the table text unchanged", function()
      local result = insert_mode.press("<A-l>", 1, 2)
      assert.are.same({ "| A | B |", "| --- | --- |", "| 1 | 2 |" }, result.lines)
    end)
  end)

  describe("without a foreign mapping", function()
    it("degrades to native cursor movement outside a table", function()
      pcall(vim.keymap.del, "i", "<A-l>")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Regular text" })
      local result = insert_mode.press("<A-l>", 1, 4)
      assert.are.same({ "Regular text" }, result.lines)
      assert.are.equal(5, result.cursor[2])
    end)

    it("degrades to native cursor movement for <A-h> outside a table", function()
      pcall(vim.keymap.del, "i", "<A-h>")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Regular text" })
      local result = insert_mode.press("<A-h>", 1, 4)
      assert.are.same({ "Regular text" }, result.lines)
      assert.are.equal(3, result.cursor[2])
    end)
  end)
end)
