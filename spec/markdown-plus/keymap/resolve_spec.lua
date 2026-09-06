---@diagnostic disable: undefined-field
local resolver = require("markdown-plus.keymap.resolve")
local mocks = require("spec.helpers.mocks")

describe("keymap resolution", function()
  local api_stub

  before_each(function()
    vim.cmd("enew")
  end)

  after_each(function()
    if api_stub then
      api_stub.restore()
      api_stub = nil
    end
    pcall(vim.keymap.del, "n", "<F5>")
    pcall(vim.keymap.del, "i", "<F5>")
    vim.cmd("bdelete!")
  end)

  it("returns nil when no mapping exists", function()
    assert.is_nil(resolver.resolve("n", "<F5>"))
  end)

  it("resolves a global string rhs mapping", function()
    vim.keymap.set("n", "<F5>", "ix<Esc>")
    local target = resolver.resolve("n", "<F5>")
    assert.is_not_nil(target)
    assert.are.equal("ix<Esc>", target.rhs)
    assert.is_nil(target.callback)
    assert.is_false(target.expr)
    assert.is_true(target.noremap)
  end)

  it("resolves a global Lua callback mapping", function()
    vim.keymap.set("n", "<F5>", function() end)
    local target = resolver.resolve("n", "<F5>")
    assert.is_not_nil(target)
    assert.are.equal("function", type(target.callback))
    assert.is_false(target.expr)
  end)

  for _, replace_keycodes in ipairs({ true, false }) do
    it("preserves expr replace_keycodes = " .. tostring(replace_keycodes), function()
      vim.keymap.set("i", "<F5>", function()
        return "<BS>"
      end, { expr = true, replace_keycodes = replace_keycodes })
      local target = resolver.resolve("i", "<F5>")
      assert.is_not_nil(target)
      assert.is_true(target.expr)
      assert.are.equal(replace_keycodes, target.replace_keycodes)
    end)
  end

  it("prefers a buffer-local foreign mapping over a global one", function()
    vim.keymap.set("n", "<F5>", "iglobal<Esc>")
    vim.keymap.set("n", "<F5>", "ibuffer<Esc>", { buffer = true })
    assert.are.equal("ibuffer<Esc>", resolver.resolve("n", "<F5>").rhs)
  end)

  it("excludes our own buffer-local default", function()
    vim.keymap.set("n", "<F5>", "iglobal<Esc>")
    vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
    assert.are.equal("iglobal<Esc>", resolver.resolve("n", "<F5>").rhs)
  end)

  it("returns nil when the only mapping is our own default", function()
    vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusListBackspace)", { buffer = true })
    assert.is_nil(resolver.resolve("n", "<F5>"))
  end)

  it("also excludes our own global mappings", function()
    vim.keymap.set("n", "<F5>", "<Plug>(MarkdownPlusListBackspace)")
    assert.is_nil(resolver.resolve("n", "<F5>"))
  end)

  it("finds mappings installed after the first lookup", function()
    assert.is_nil(resolver.resolve("n", "<F5>"))
    vim.keymap.set("n", "<F5>", "ilate<Esc>")
    assert.are.equal("ilate<Esc>", resolver.resolve("n", "<F5>").rhs)
  end)

  it("matches equivalent key notations", function()
    vim.keymap.set("n", "<F5>", "ix<Esc>")
    assert.are.equal("ix<Esc>", resolver.resolve("n", "<f5>").rhs)
  end)

  it("caches normalization without caching mappings", function()
    local original = vim.api.nvim_replace_termcodes
    api_stub = mocks.stub_fn(vim.api, "nvim_replace_termcodes", original)
    local first = resolver.normalize("<F33>")
    assert.are.equal(first, resolver.normalize("<F33>"))
    assert.are.equal(1, #api_stub.calls)
  end)

  it("still finds a global mapping if buffer lookup fails", function()
    vim.keymap.set("n", "<F5>", "iglobal<Esc>")
    api_stub = mocks.stub_fn(vim.api, "nvim_buf_get_keymap", function()
      error("unavailable")
    end)
    assert.are.equal("iglobal<Esc>", resolver.resolve("n", "<F5>").rhs)
  end)

  it("returns nil if the global lookup fails and there is no local match", function()
    api_stub = mocks.stub_fn(vim.api, "nvim_get_keymap", function()
      error("unavailable")
    end)
    assert.is_nil(resolver.resolve("n", "<F5>"))
  end)
end)
