---@diagnostic disable: undefined-field
local cell_breaks = require("markdown-plus.table.cell_breaks")

describe("table.cell_breaks", function()
  describe("split_segments", function()
    it("returns a single segment when no break is present", function()
      assert.are.same({ "hello world" }, cell_breaks.split_segments("hello world"))
    end)

    it("returns one empty segment for empty input", function()
      assert.are.same({ "" }, cell_breaks.split_segments(""))
    end)

    it("returns one empty segment for nil input", function()
      assert.are.same({ "" }, cell_breaks.split_segments(nil))
    end)

    it("splits on a single <br>", function()
      assert.are.same({ "aaa", "bbb" }, cell_breaks.split_segments("aaa<br>bbb"))
    end)

    it("splits on <br/> (XHTML form)", function()
      assert.are.same({ "aaa", "bbb" }, cell_breaks.split_segments("aaa<br/>bbb"))
    end)

    it("splits on <br /> (with internal whitespace)", function()
      assert.are.same({ "aaa", "bbb" }, cell_breaks.split_segments("aaa<br />bbb"))
    end)

    it("is case-insensitive (<BR>, <Br>, <bR>)", function()
      assert.are.same({ "a", "b" }, cell_breaks.split_segments("a<BR>b"))
      assert.are.same({ "a", "b" }, cell_breaks.split_segments("a<Br>b"))
      assert.are.same({ "a", "b" }, cell_breaks.split_segments("a<bR/>b"))
    end)

    it("splits on multiple breaks", function()
      assert.are.same({ "one", "two", "three" }, cell_breaks.split_segments("one<br>two<br>three"))
    end)

    it("preserves empty segments from consecutive breaks", function()
      assert.are.same({ "a", "", "b" }, cell_breaks.split_segments("a<br><br>b"))
    end)

    it("preserves leading empty segment when <br> is at the start", function()
      assert.are.same({ "", "tail" }, cell_breaks.split_segments("<br>tail"))
    end)

    it("preserves trailing empty segment when <br> is at the end", function()
      assert.are.same({ "head", "" }, cell_breaks.split_segments("head<br>"))
    end)

    it("preserves surrounding whitespace in segments", function()
      assert.are.same({ "aa ", " bb" }, cell_breaks.split_segments("aa <br> bb"))
    end)

    it("does not split <br> inside an inline code span", function()
      assert.are.same({ "use `<br>` for breaks" }, cell_breaks.split_segments("use `<br>` for breaks"))
    end)

    it("splits real <br> after an inline code span ends", function()
      assert.are.same({ "code `<br>` here", "next line" }, cell_breaks.split_segments("code `<br>` here<br>next line"))
    end)

    it("handles a code span before a real break", function()
      assert.are.same({ "`<br>` plus text", "more" }, cell_breaks.split_segments("`<br>` plus text<br>more"))
    end)

    it("preserves escaped pipes adjacent to <br>", function()
      assert.are.same({ "col\\|a", "col\\|b" }, cell_breaks.split_segments("col\\|a<br>col\\|b"))
    end)
  end)

  describe("has_break", function()
    it("returns false for plain text", function()
      assert.is_false(cell_breaks.has_break("just text"))
    end)

    it("returns false for empty/nil", function()
      assert.is_false(cell_breaks.has_break(""))
      assert.is_false(cell_breaks.has_break(nil))
    end)

    it("returns true for <br>, <br/>, <br />", function()
      assert.is_true(cell_breaks.has_break("a<br>b"))
      assert.is_true(cell_breaks.has_break("a<br/>b"))
      assert.is_true(cell_breaks.has_break("a<br />b"))
    end)

    it("is case-insensitive", function()
      assert.is_true(cell_breaks.has_break("a<BR>b"))
      assert.is_true(cell_breaks.has_break("a<Br/>b"))
    end)

    it("returns false when <br> is only inside an inline code span", function()
      assert.is_false(cell_breaks.has_break("use `<br>` here"))
    end)

    it("returns true when a real break exists outside the code span", function()
      assert.is_true(cell_breaks.has_break("`<br>` and<br>more"))
    end)
  end)

  describe("join_segments", function()
    it("joins with the default <br> token", function()
      assert.equals("a<br>b<br>c", cell_breaks.join_segments({ "a", "b", "c" }))
    end)

    it("joins with a custom token", function()
      assert.equals("a  \nb", cell_breaks.join_segments({ "a", "b" }, "  \n"))
    end)

    it("returns empty string for nil or empty input", function()
      assert.equals("", cell_breaks.join_segments(nil))
      assert.equals("", cell_breaks.join_segments({}))
    end)

    it("preserves empty segments so consecutive breaks round-trip", function()
      assert.equals("a<br><br>b", cell_breaks.join_segments({ "a", "", "b" }))
    end)

    it("round-trips split -> join with default token", function()
      local original = "alpha<br>beta<br>gamma"
      local segs = cell_breaks.split_segments(original)
      assert.equals(original, cell_breaks.join_segments(segs))
    end)
  end)

  describe("unwrap", function()
    it("returns input unchanged when no break is present", function()
      assert.equals("hello world", cell_breaks.unwrap("hello world"))
    end)

    it("replaces a single <br> with a space", function()
      assert.equals("a b", cell_breaks.unwrap("a<br>b"))
    end)

    it("collapses surrounding whitespace around breaks", function()
      assert.equals("aa bb", cell_breaks.unwrap("aa <br> bb"))
    end)

    it("collapses consecutive breaks to a single space", function()
      assert.equals("a b", cell_breaks.unwrap("a<br><br>b"))
    end)

    it("trims leading and trailing whitespace from break-only edges", function()
      assert.equals("tail", cell_breaks.unwrap("<br>tail"))
      assert.equals("head", cell_breaks.unwrap("head<br>"))
    end)

    it("leaves <br> inside inline code spans intact", function()
      assert.equals("use `<br>` for breaks", cell_breaks.unwrap("use `<br>` for breaks"))
    end)

    it("handles empty/nil input", function()
      assert.equals("", cell_breaks.unwrap(""))
      assert.equals("", cell_breaks.unwrap(nil))
    end)
  end)
end)
