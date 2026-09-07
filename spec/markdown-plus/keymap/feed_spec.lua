---@diagnostic disable: undefined-field
local feed = require("markdown-plus.keymap.feed")
local mocks = require("spec.helpers.mocks")

---Expand notation without the lhs-specific normalization mode.
---@param keys string
---@return string
local function termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

describe("keymap feeding", function()
  local queued
  local target

  before_each(function()
    queued = mocks.stub_fn(vim.api, "nvim_feedkeys", function() end)
    target = { expr = false, noremap = true, replace_keycodes = true }
  end)

  after_each(function()
    queued.restore()
  end)

  it("feeds raw keys at the front without remapping", function()
    feed.raw("<BS>")
    assert.are.same({ { termcodes("<BS>"), "ni", false } }, queued.calls)
  end)

  it("prefixes counts only when greater than one", function()
    feed.raw("x", 1)
    feed.raw("x", 3)
    assert.are.same({ { "x", "ni", false }, { "3x", "ni", false } }, queued.calls)
  end)

  it("restores a count for a noremap target", function()
    feed.target("x", target, "<F5>", 3)
    assert.are.same({ { "3x", "ni", false } }, queued.calls)
  end)

  it("leaves foreign targets remappable without prefixing counts", function()
    target.noremap = false
    feed.target(termcodes("<F6>"), target, "<F5>", 3)
    assert.are.same({ { termcodes("<F6>"), "mi", false } }, queued.calls)
  end)

  it("feeds the remainder before a protected lhs prefix to preserve execution order", function()
    target.noremap = false
    feed.target(termcodes("<F5><F6>"), target, "<F5>")
    assert.are.same({
      { termcodes("<F6>"), "mi", false },
      { termcodes("<F5>"), "ni", false },
    }, queued.calls)
  end)

  it("feeds an exact lhs match once without remapping", function()
    target.noremap = false
    feed.target(termcodes("<F5>"), target, "<F5>")
    assert.are.same({ { termcodes("<F5>"), "ni", false } }, queued.calls)
  end)

  it("does not substitute the protected prefix of a remappable target", function()
    target.noremap = false
    feed.target(termcodes("<F5>"), target, "<F5>", 3, "x")
    assert.are.same({ { termcodes("<F5>"), "ni", false } }, queued.calls)
  end)

  it("allows an empty lhs without treating it as a recursive prefix", function()
    target.noremap = false
    feed.target("x", target, "")
    assert.are.same({ { "x", "mi", false } }, queued.calls)
  end)

  for _, encoded in ipairs({ false, true }) do
    it("degrades our own Plug bounce with encoded = " .. tostring(encoded), function()
      local keys = "<Plug>(MarkdownPlusFallbackSpec)"
      feed.target(encoded and termcodes(keys) or keys, target, "<F5>", 3, "x")
      assert.are.same({ { "3x", "ni", false } }, queued.calls)
    end)
  end

  it("uses the lhs when an own-Plug bounce has no substitute", function()
    feed.target("<Plug>(MarkdownPlusFallbackSpec)", target, "x")
    assert.are.same({ { "x", "ni", false } }, queued.calls)
  end)

  it("does not treat another plugin's Plug as our own", function()
    target.noremap = false
    local keys = termcodes("<Plug>(ForeignPlugin)")
    feed.target(keys, target, "<F5>")
    assert.are.same({ { keys, "mi", false } }, queued.calls)
  end)

  it("expands expression results when requested", function()
    feed.expr_result("<BS>", target, "<F5>")
    assert.are.same({ { termcodes("<BS>"), "ni", false } }, queued.calls)
  end)

  it("preserves already-expanded expression results", function()
    target.replace_keycodes = false
    feed.expr_result(termcodes("<BS>"), target, "<F5>")
    assert.are.same({ { termcodes("<BS>"), "ni", false } }, queued.calls)
  end)

  it("passes count and substitute through expression bounce handling", function()
    feed.expr_result("<Plug>(MarkdownPlusFallbackSpec)", target, "<F5>", 3, "x")
    assert.are.same({ { "3x", "ni", false } }, queued.calls)
  end)

  it("does not feed empty or non-string expression results", function()
    feed.expr_result("", target, "<F5>")
    feed.expr_result(nil, target, "<F5>")
    feed.expr_result(false, target, "<F5>")
    assert.are.same({}, queued.calls)
  end)
end)
