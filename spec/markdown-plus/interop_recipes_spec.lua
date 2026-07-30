---End-to-end tests for the composition recipes published in README.md and
---doc/markdown-plus.txt (|markdown-plus-recipes|).
---
---The mappings below are copied verbatim from the documentation, with one substitution: the
---`mini.pairs` call becomes a local stand-in, because the plugin is not a test dependency. Its
---return value (`<BS><Del>`, deleting both sides of a pair) is the shape `mini.pairs.bs()`
---produces, so the termcode handling under test is unchanged.
---
---Docs that do not run are docs that rot: these recipes are user-facing API surface and must
---keep working across changes to the fallback and context layers.
---@diagnostic disable: undefined-field
local insert_mode = require("spec.helpers.insert_mode")

describe("markdown-plus interop recipes", function()
  local buf

  ---Stand-in for `require("mini.pairs")` in the documented `<BS>` recipe
  local mini_pairs = {
    bs = function()
      return "<BS><Del>"
    end,
  }

  before_each(function()
    require("markdown-plus").setup({})
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
  end)

  after_each(function()
    for _, lhs in ipairs({ "<BS>", "<CR>", "<Tab>" }) do
      pcall(vim.keymap.del, "i", lhs, { buffer = buf })
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("mini.pairs <BS> recipe", function()
    before_each(function()
      vim.keymap.set("i", "<BS>", function()
        if require("markdown-plus").in_list_context("backspace") then
          return "<Plug>(MarkdownPlusListBackspace)"
        end
        return mini_pairs.bs()
      end, { expr = true, buffer = true })
    end)

    it("removes the list marker at the start of list content", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
      local result = insert_mode.press("<BS>", 1, 2)
      assert.are.same({ "item" }, result.lines)
    end)

    it("runs the pairs handler mid-content inside a list item", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- ()" })
      local result = insert_mode.press("<BS>", 1, 3)
      assert.are.same({ "- " }, result.lines)
    end)

    it("runs the pairs handler on a plain line", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "()" })
      local result = insert_mode.press("<BS>", 1, 1)
      assert.are.same({ "" }, result.lines)
    end)
  end)

  describe("completion <CR> recipe", function()
    before_each(function()
      vim.keymap.set("i", "<CR>", function()
        if vim.fn.pumvisible() == 1 then
          return "<C-y>"
        end
        if require("markdown-plus").in_list_context("enter") then
          return "<Plug>(MarkdownPlusListEnter)"
        end
        return "<CR>"
      end, { expr = true, buffer = true })
    end)

    it("continues the list in list context", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- Item" })
      local result = insert_mode.press("<CR>", 1, 6)
      assert.are.same({ "- Item", "- " }, result.lines)
    end)

    it("inserts a plain newline outside list context", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain" })
      local result = insert_mode.press("<CR>", 1, 5)
      assert.are.same({ "plain", "" }, result.lines)
    end)
  end)

  describe("snippet <Tab> recipe", function()
    before_each(function()
      vim.keymap.set("i", "<Tab>", function()
        if require("markdown-plus").in_list_context("indent") then
          return "<Plug>(MarkdownPlusListIndent)"
        end
        return "<Tab>"
      end, { expr = true, buffer = true })
    end)

    it("indents the list item in list context", function()
      vim.bo[buf].shiftwidth = 2
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- item" })
      local result = insert_mode.press("<Tab>", 1, 2)
      assert.are.same({ "  - item" }, result.lines)
    end)

    it("inserts a literal tab outside list context", function()
      vim.bo[buf].expandtab = false
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain" })
      local result = insert_mode.press("<Tab>", 1, 5)
      assert.are.same({ "plain\t" }, result.lines)
    end)
  end)
end)
