---@diagnostic disable: undefined-field
local markdown_plus = require("markdown-plus")

local MODULES = {
  {
    name = "code_block",
    key = "]b",
    plug = "<Plug>(MarkdownPlusCodeBlockNext)",
    prefix = "<Plug>(MarkdownPlusCodeBlock",
  },
  {
    name = "table",
    key = ",tf",
    plug = "<Plug>(MarkdownPlusTableFormat)",
    prefix = "<Plug>(MarkdownPlusTable",
  },
}

describe("module enabled flags", function()
  local buffers
  local original_localleader
  local original_global_mappings

  ---@param lines string[]
  ---@return integer
  local function new_markdown_buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    buffers[#buffers + 1] = buf
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo.filetype = "markdown"
    return buf
  end

  ---@param feature { name: string, key: string, plug: string, prefix: string }
  ---@param buf integer
  ---@param enabled boolean
  ---@return nil
  local function assert_defaults(feature, buf, enabled)
    local count = 0
    for _, mode in ipairs({ "n", "x", "i" }) do
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
        -- The bare CodeBlock Plug belongs to the independent text-formatting feature.
        if
          type(mapping.rhs) == "string"
          and mapping.rhs:find(feature.prefix, 1, true) == 1
          and mapping.rhs ~= "<Plug>(MarkdownPlusCodeBlock)"
        then
          count = count + 1
        end
      end
    end
    assert.are.equal(enabled, count > 0, feature.name .. " buffer-local defaults")
    if enabled then
      vim.api.nvim_buf_call(buf, function()
        local mapping = vim.fn.maparg(feature.key, "n", false, true)
        assert.are.equal(feature.plug, mapping.rhs)
        assert.are.equal(1, mapping.buffer)
      end)
    end
  end

  ---@param keys string
  ---@return nil
  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
  end

  ---@param code_block_key string
  ---@param table_key string
  ---@return nil
  local function exercise_mapped_operations(code_block_key, table_key)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "intro",
      "```lua",
      "print('hello')",
      "```",
      "",
      "| H |",
      "| --- |",
      "| value |",
    })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    feed(code_block_key)
    assert.are.same({ 2, 0 }, vim.api.nvim_win_get_cursor(0))

    vim.api.nvim_win_set_cursor(0, { 8, 2 })
    feed(table_key)
    assert.are.same({ "| H     |", "| ----- |", "| value |" }, vim.api.nvim_buf_get_lines(0, 5, -1, false))
  end

  before_each(function()
    markdown_plus.teardown()
    buffers = {}
    original_global_mappings = {}
    original_localleader = vim.g.maplocalleader
    vim.g.maplocalleader = ","
  end)

  after_each(function()
    feed("<Esc>")
    markdown_plus.teardown()
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    for key, mapping in pairs(original_global_mappings) do
      vim.keymap.del("n", key)
      if next(mapping) then
        vim.fn.mapset("n", false, mapping)
      end
    end
    vim.g.maplocalleader = original_localleader
  end)

  it("does not install code-block defaults when disabled at initial setup", function()
    markdown_plus.setup({ code_block = { enabled = false } })
    new_markdown_buffer({ "text" })

    assert.is_nil(vim.fn.maparg("]b", "n", false, true).rhs)
  end)

  it("does not install table defaults when disabled at initial setup", function()
    markdown_plus.setup({ table = { enabled = false } })
    new_markdown_buffer({ "| H |", "| --- |", "| value |" })

    assert.is_nil(vim.fn.maparg(",tf", "n", false, true).rhs)
  end)

  for _, feature in ipairs(MODULES) do
    describe(feature.name, function()
      it("skips activation in already-open buffers when the module is disabled", function()
        local buf = new_markdown_buffer({ "text" })
        markdown_plus.setup({ [feature.name] = { enabled = false } })

        assert_defaults(feature, buf, false)
        assert.is_nil(markdown_plus[feature.name])
        assert.is_true(markdown_plus.config.features[feature.name])
        assert.is_false(markdown_plus.config[feature.name].enabled)
      end)

      it("removes owned defaults from all loaded buffers and skips later activation", function()
        markdown_plus.setup({})
        local first = new_markdown_buffer({ "first" })
        local second = new_markdown_buffer({ "second" })
        assert_defaults(feature, first, true)
        assert_defaults(feature, second, true)

        markdown_plus.setup({ [feature.name] = { enabled = false } })

        assert_defaults(feature, first, false)
        assert_defaults(feature, second, false)
        assert.is_nil(markdown_plus[feature.name])
        vim.api.nvim_exec_autocmds("FileType", { buffer = first })
        assert_defaults(feature, first, false)
        assert_defaults(feature, new_markdown_buffer({ "third" }), false)
      end)

      for _, reenable in ipairs({ "explicitly", "by restoring defaults" }) do
        it("re-enables existing and new buffers " .. reenable, function()
          markdown_plus.setup({ [feature.name] = { enabled = false } })
          local first = new_markdown_buffer({ "first" })
          local second = new_markdown_buffer({ "second" })
          local options = reenable == "explicitly" and { [feature.name] = { enabled = true } } or {}

          markdown_plus.setup(options)

          assert.is_not_nil(markdown_plus[feature.name])
          assert.is_true(markdown_plus.config[feature.name].enabled)
          assert_defaults(feature, first, true)
          assert_defaults(feature, second, true)
          assert_defaults(feature, new_markdown_buffer({ "third" }), true)
        end)
      end

      it("does not override an independent disabled feature flag", function()
        local buf = new_markdown_buffer({ "text" })
        markdown_plus.setup({
          features = { [feature.name] = false },
          [feature.name] = { enabled = true },
        })

        assert.is_nil(markdown_plus[feature.name])
        assert.is_false(markdown_plus.config.features[feature.name])
        assert.is_true(markdown_plus.config[feature.name].enabled)
        assert_defaults(feature, buf, false)
        assert_defaults(feature, new_markdown_buffer({ "another" }), false)
      end)

      it("does not activate a disabled module when default keymaps are also disabled", function()
        local buf = new_markdown_buffer({ "text" })
        markdown_plus.setup({
          keymaps = { enabled = false },
          [feature.name] = { enabled = false },
        })

        assert.is_nil(markdown_plus[feature.name])
        assert_defaults(feature, buf, false)
        assert_defaults(feature, new_markdown_buffer({ "another" }), false)
      end)

      it("keeps an enabled module and its Plugs available without default keymaps", function()
        markdown_plus.setup({})
        local buf = new_markdown_buffer({ "text" })
        assert_defaults(feature, buf, true)

        markdown_plus.setup({ keymaps = { enabled = false } })

        assert.is_not_nil(markdown_plus[feature.name])
        assert.is_true(markdown_plus.config.features[feature.name])
        assert_defaults(feature, buf, false)
        assert_defaults(feature, new_markdown_buffer({ "another" }), false)
        assert.is_function(vim.fn.maparg(feature.plug, "n", false, true).callback)
      end)

      it("preserves pre-existing personal mappings to the module's Plug", function()
        new_markdown_buffer({ "text" })
        vim.keymap.set("n", feature.key, feature.plug, { buffer = true, desc = "Personal mapping" })

        for _, enabled in ipairs({ false, true, false, true }) do
          markdown_plus.setup({ [feature.name] = { enabled = enabled } })
          local mapping = vim.fn.maparg(feature.key, "n", false, true)
          assert.are.equal(feature.plug, mapping.rhs)
          assert.are.equal("Personal mapping", mapping.desc)
          assert.are.equal(1, mapping.buffer)
        end
      end)

      it("preserves and executes foreign replacements of owned defaults", function()
        markdown_plus.setup({})
        new_markdown_buffer({ "text" })
        local calls = 0
        local description = vim.fn.maparg(feature.key, "n", false, true).desc
        local replacement = function()
          calls = calls + 1
        end
        vim.keymap.set("n", feature.key, replacement, { buffer = true, desc = description })

        for index, enabled in ipairs({ false, true }) do
          markdown_plus.setup({ [feature.name] = { enabled = enabled } })
          assert.are.equal(replacement, vim.fn.maparg(feature.key, "n", false, true).callback)
          feed(feature.key)
          assert.are.equal(index, calls)
        end
      end)
    end)
  end

  it("keeps module activation independent from the other module's flag", function()
    for _, disabled in ipairs(MODULES) do
      markdown_plus.setup({ [disabled.name] = { enabled = false } })
      local buf = new_markdown_buffer({ "text" })
      for _, feature in ipairs(MODULES) do
        assert_defaults(feature, buf, feature.name ~= disabled.name)
      end
    end
  end)

  it("keeps legacy text-formatting defaults independent from code-block activation", function()
    markdown_plus.setup({ code_block = { enabled = false } })
    new_markdown_buffer({ "text" })
    assert.is_nil(markdown_plus.code_block)
    assert.are.equal("<Plug>(MarkdownPlusCodeBlock)", vim.fn.maparg(",mw", "x", false, true).rhs)
    assert.are.equal("<Plug>(MarkdownPlusBold)", vim.fn.maparg(",mb", "n", false, true).rhs)

    markdown_plus.setup({
      features = { text_formatting = false },
      code_block = { enabled = false },
    })
    assert.is_nil(vim.fn.maparg(",mw", "x", false, true).rhs)
  end)

  it("executes enabled defaults and reveals foreign global mappings while disabled", function()
    local calls = { code_block = 0, table = 0 }
    for _, feature in ipairs(MODULES) do
      local name = feature.name
      original_global_mappings[feature.key] = vim.fn.maparg(feature.key, "n", false, true)
      vim.keymap.set("n", feature.key, function()
        calls[name] = calls[name] + 1
      end)
    end
    markdown_plus.setup({})
    new_markdown_buffer({ "text" })

    exercise_mapped_operations("]b", ",tf")
    assert.are.same({ code_block = 0, table = 0 }, calls)

    markdown_plus.setup({ code_block = { enabled = false }, table = { enabled = false } })
    local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    feed("]b,tf")
    assert.are.same({ code_block = 1, table = 1 }, calls)
    assert.are.same(before, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    markdown_plus.setup({})
    exercise_mapped_operations("]b", ",tf")
    assert.are.same({ code_block = 1, table = 1 }, calls)
  end)

  it("executes custom Plug mappings with global defaults disabled", function()
    markdown_plus.setup({ keymaps = { enabled = false } })
    local buf = new_markdown_buffer({ "text" })
    for _, feature in ipairs(MODULES) do
      assert_defaults(feature, buf, false)
    end

    vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusCodeBlockNext)", { buffer = true })
    vim.keymap.set("n", "<F6>", "<Plug>(MarkdownPlusTableFormat)", { buffer = true })
    exercise_mapped_operations("<F5>", "<F6>")
  end)

  it("disables only table defaults through table.keymaps.enabled", function()
    markdown_plus.setup({ table = { keymaps = { enabled = false } } })
    local buf = new_markdown_buffer({ "text" })
    assert.is_not_nil(markdown_plus.table)
    assert_defaults(MODULES[1], buf, true)
    assert_defaults(MODULES[2], buf, false)

    exercise_mapped_operations("]b", "<Plug>(MarkdownPlusTableFormat)")
  end)

  it("honors custom table prefixes and insert-navigation controls after re-enabling", function()
    local options = { table = { keymaps = { prefix = ",z", insert_mode_navigation = false } } }
    markdown_plus.setup(options)
    local buf = new_markdown_buffer({ "text" })
    assert.are.equal("<Plug>(MarkdownPlusTableFormat)", vim.fn.maparg(",zf", "n", false, true).rhs)
    assert.is_nil(vim.fn.maparg(",tf", "n", false, true).rhs)
    assert.is_nil(vim.fn.maparg("<A-l>", "i", false, true).rhs)

    options.table.enabled = false
    markdown_plus.setup(options)
    assert_defaults(MODULES[2], buf, false)

    options.table.enabled = true
    markdown_plus.setup(options)
    assert.are.equal("<Plug>(MarkdownPlusTableFormat)", vim.fn.maparg(",zf", "n", false, true).rhs)
    assert.is_nil(vim.fn.maparg("<A-l>", "i", false, true).rhs)
    exercise_mapped_operations("]b", ",zf")
  end)
end)
