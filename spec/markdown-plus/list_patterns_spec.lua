---Test suite for markdown-plus.nvim list patterns module
---Verifies static pattern data, PATTERN_CONFIG ordering, and treesitter maps
---@diagnostic disable: undefined-field
local patterns = require("markdown-plus.list.patterns")

describe("markdown-plus list patterns", function()
  describe("delimiter constants", function()
    it("exposes dot and paren delimiters", function()
      assert.are.equal(".", patterns.DELIMITER_DOT)
      assert.are.equal(")", patterns.DELIMITER_PAREN)
    end)
  end)

  describe("treesitter type maps", function()
    it("maps marker nodes to list types", function()
      assert.is_not_nil(patterns.TS_MARKER_TYPES)
      local has_unordered, has_ordered = false, false
      for _, info in pairs(patterns.TS_MARKER_TYPES) do
        if info.type == "unordered" then
          has_unordered = true
        elseif info.type == "ordered" or info.type == "ordered_paren" then
          has_ordered = true
        end
      end
      assert.is_true(has_unordered)
      assert.is_true(has_ordered)
    end)

    it("maps checkbox nodes to states", function()
      assert.is_not_nil(patterns.TS_CHECKBOX_TYPES)
      local states = {}
      for _, state in pairs(patterns.TS_CHECKBOX_TYPES) do
        states[state] = true
      end
      assert.is_true(states[" "])
      assert.is_true(states["x"])
    end)
  end)

  describe("patterns table", function()
    ---Sample inputs that should match each pattern (with captures present)
    local cases = {
      unordered = "- item",
      ordered = "1. item",
      checkbox = "- [ ] item",
      ordered_checkbox = "1. [x] item",
      letter_lower = "a. item",
      letter_upper = "A. item",
      letter_lower_checkbox = "a. [ ] item",
      letter_upper_checkbox = "A. [x] item",
      ordered_paren = "1) item",
      letter_lower_paren = "a) item",
      letter_upper_paren = "A) item",
      ordered_paren_checkbox = "1) [ ] item",
      letter_lower_paren_checkbox = "a) [x] item",
      letter_upper_paren_checkbox = "A) [ ] item",
      unordered_empty = "-",
      ordered_empty = "1.",
      letter_lower_empty = "a.",
      letter_upper_empty = "A.",
      ordered_paren_empty = "1)",
      letter_lower_paren_empty = "a)",
      letter_upper_paren_empty = "A)",
    }

    it("defines all expected pattern keys", function()
      for key in pairs(cases) do
        assert.is_string(patterns.patterns[key], "missing pattern: " .. key)
      end
    end)

    it("matches representative inputs for every pattern", function()
      for key, input in pairs(cases) do
        local m = input:match(patterns.patterns[key])
        assert.is_not_nil(m, "pattern did not match: " .. key .. " input=" .. input)
      end
    end)

    it("indents are captured by patterns", function()
      local indent = ("  - item"):match(patterns.patterns.unordered)
      assert.are.equal("  ", indent)
    end)
  end)

  describe("PATTERN_CONFIG ordering", function()
    it("places checkbox variants before their non-checkbox counterparts", function()
      local idx = {}
      for i, config in ipairs(patterns.PATTERN_CONFIG) do
        idx[config.pattern] = i
      end
      assert.is_true(idx.ordered_checkbox < idx.ordered)
      assert.is_true(idx.checkbox < idx.unordered)
      assert.is_true(idx.letter_lower_checkbox < idx.letter_lower)
    end)

    it("places empty patterns last and flags them is_empty", function()
      local first_empty = nil
      for i, config in ipairs(patterns.PATTERN_CONFIG) do
        if config.is_empty and not first_empty then
          first_empty = i
        end
        if first_empty and not config.is_empty then
          -- A non-empty pattern appears after an empty one: fail
          assert.is_true(false, "non-empty pattern after empty at index " .. i)
        end
      end
      assert.is_not_nil(first_empty)
    end)

    it("every config references a defined pattern", function()
      for _, config in ipairs(patterns.PATTERN_CONFIG) do
        assert.is_string(patterns.patterns[config.pattern], "undefined pattern: " .. config.pattern)
      end
    end)
  end)
end)
