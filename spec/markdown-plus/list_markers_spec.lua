---Test suite for markdown-plus.nvim list markers module
---Verifies marker sequence arithmetic: index_to_letter, next_letter, next/previous markers
---@diagnostic disable: undefined-field
local markers = require("markdown-plus.list.markers")

describe("markdown-plus list markers", function()
  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("index_to_letter", function()
    it("maps 1 to a and 26 to z (lowercase)", function()
      assert.are.equal("a", markers.index_to_letter(1, false))
      assert.are.equal("z", markers.index_to_letter(26, false))
    end)

    it("wraps 27 back to a", function()
      assert.are.equal("a", markers.index_to_letter(27, false))
    end)

    it("supports uppercase", function()
      assert.are.equal("A", markers.index_to_letter(1, true))
      assert.are.equal("Z", markers.index_to_letter(26, true))
      assert.are.equal("A", markers.index_to_letter(27, true))
    end)
  end)

  describe("next_letter", function()
    it("increments within range", function()
      assert.are.equal("b", markers.next_letter("a", false))
      assert.are.equal("B", markers.next_letter("A", true))
    end)

    it("wraps z to a and Z to A", function()
      assert.are.equal("a", markers.next_letter("z", false))
      assert.are.equal("A", markers.next_letter("Z", true))
    end)
  end)

  describe("get_next_marker", function()
    it("increments ordered dot markers", function()
      assert.are.equal("2.", markers.get_next_marker({ type = "ordered", marker = "1." }))
    end)

    it("increments ordered paren markers", function()
      assert.are.equal("2)", markers.get_next_marker({ type = "ordered_paren", marker = "1)" }))
    end)

    it("increments lowercase letter markers", function()
      assert.are.equal("b.", markers.get_next_marker({ type = "letter_lower", marker = "a." }))
      assert.are.equal("b)", markers.get_next_marker({ type = "letter_lower_paren", marker = "a)" }))
    end)

    it("increments uppercase letter markers", function()
      assert.are.equal("B.", markers.get_next_marker({ type = "letter_upper", marker = "A." }))
      assert.are.equal("B)", markers.get_next_marker({ type = "letter_upper_paren", marker = "A)" }))
    end)

    it("returns the same marker for unordered lists", function()
      assert.are.equal("-", markers.get_next_marker({ type = "unordered", marker = "-" }))
      assert.are.equal("*", markers.get_next_marker({ type = "unordered", marker = "*" }))
    end)
  end)

  describe("get_previous_marker", function()
    it("returns initial marker when there is no preceding sibling", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1. first" })
      local info = { type = "ordered", marker = "1.", indent = "" }
      assert.are.equal("1.", markers.get_previous_marker(info, 1))
    end)

    it("returns incremented marker from a preceding ordered sibling", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "2. second", "3. third" })
      local info = { type = "ordered", marker = "3.", indent = "" }
      assert.are.equal("3.", markers.get_previous_marker(info, 2))
    end)

    it("returns incremented marker from a preceding lowercase letter sibling", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a. first", "b. second" })
      local info = { type = "letter_lower", marker = "b.", indent = "" }
      assert.are.equal("b.", markers.get_previous_marker(info, 2))
    end)

    it("returns initial letter markers when no sibling found", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a. only" })
      assert.are.equal("a.", markers.get_previous_marker({ type = "letter_lower", marker = "a.", indent = "" }, 1))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "A) only" })
      assert.are.equal(
        "A)",
        markers.get_previous_marker({ type = "letter_upper_paren", marker = "A)", indent = "" }, 1)
      )
    end)

    it("keeps the bullet for unordered lists", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
      assert.are.equal("-", markers.get_previous_marker({ type = "unordered", marker = "-", indent = "" }, 1))
    end)
  end)
end)
