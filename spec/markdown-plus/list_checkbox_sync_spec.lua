---Test suite for parent/child checkbox sync (`list.checkbox_sync`)
---@diagnostic disable: undefined-field
local list = require("markdown-plus.list")
local checkbox_sync = require("markdown-plus.list.checkbox_sync")

describe("markdown-plus checkbox sync", function()
  local buf
  local markdown_plus
  local original_list_config
  local original_features

  ---@param lines string[]
  local function set_lines(lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  ---@return string[]
  local function get_lines()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
    markdown_plus = require("markdown-plus")
    original_list_config = markdown_plus.config.list
    original_features = markdown_plus.config.features
    markdown_plus.config.features = vim.tbl_extend("force", original_features or {}, { html_block_awareness = true })
    markdown_plus.config.list = vim.tbl_deep_extend("force", vim.deepcopy(original_list_config or {}), {
      checkbox_sync = true,
      checkbox_completion = { enabled = false },
    })
    list.setup(markdown_plus.config)
  end)

  after_each(function()
    markdown_plus.config.list = original_list_config
    markdown_plus.config.features = original_features
    list.setup(markdown_plus.config)
    vim.cmd("stopinsert")
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("build_tree", function()
    for _, delimiters in ipairs({ { "<div>", "</div>" }, { "<!--", "-->" }, { "<script>", "</script>" } }) do
      it("excludes " .. delimiters[1] .. " HTML blocks without disturbing surrounding list ancestry", function()
        local nodes = checkbox_sync.build_tree({
          "- [ ] parent",
          "  " .. delimiters[1],
          "  - [ ] HTML example",
          "  ```",
          "  " .. delimiters[2],
          "",
          "  - [ ] real child",
        })
        assert.is_nil(nodes[3])
        assert.are.equal(nodes[1], nodes[7].parent)
      end)
    end

    it("nests list items by indentation", function()
      local nodes = checkbox_sync.build_tree({
        "- [ ] parent",
        "  - [x] child",
        "    - grandchild",
        "- [ ] sibling",
      })
      assert.is_nil(nodes[1].parent)
      assert.are.equal(nodes[1], nodes[2].parent)
      assert.are.equal(nodes[2], nodes[3].parent)
      assert.is_nil(nodes[3].state)
      assert.is_nil(nodes[4].parent)
      assert.are.equal("x", nodes[2].state)
    end)

    it("ignores list-like lines inside fenced code blocks", function()
      local nodes = checkbox_sync.build_tree({
        "- [ ] parent",
        "  ```markdown",
        "  - [ ] not a task",
        "  ```",
        "  - [ ] child",
      })
      assert.is_nil(nodes[3])
      assert.are.equal(nodes[1], nodes[5].parent)
    end)

    it("ends a list at an unindented paragraph", function()
      local nodes = checkbox_sync.build_tree({
        "- [ ] task",
        "Paragraph",
        "  - [ ] unrelated",
      })
      assert.is_nil(nodes[3].parent)
    end)
  end)

  describe("when disabled (default)", function()
    it("only toggles the current line", function()
      markdown_plus.config.list.checkbox_sync = false
      set_lines({ "- [ ] parent", "  - [ ] child" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [x] parent", "  - [ ] child" }, get_lines())
    end)
  end)

  describe("downward", function()
    it("updates real children but leaves HTML-block tasks unchanged", function()
      set_lines({
        "- [ ] parent",
        "  <div>",
        "  - [ ] HTML example",
        "  </div>",
        "",
        "  - [ ] real child",
      })
      list.toggle_checkbox_on_line(1)
      assert.are.same({
        "- [x] parent",
        "  <div>",
        "  - [ ] HTML example",
        "  </div>",
        "",
        "  - [x] real child",
      }, get_lines())
    end)

    it("includes HTML-block tasks when HTML awareness is disabled", function()
      markdown_plus.config.features.html_block_awareness = false
      list.setup(markdown_plus.config)
      set_lines({ "- [ ] parent", "  <div>", "  - [ ] HTML example", "  </div>", "", "  - [ ] real child" })
      list.toggle_checkbox_on_line(1)
      assert.are.same(
        { "- [x] parent", "  <div>", "  - [x] HTML example", "  </div>", "", "  - [x] real child" },
        get_lines()
      )
    end)

    it("checks every descendant when checking a parent", function()
      set_lines({
        "- [ ] parent",
        "  - [ ] child",
        "    - [ ] grandchild",
        "  - [x] done child",
        "- [ ] sibling",
      })
      list.toggle_checkbox_on_line(1)
      assert.are.same({
        "- [x] parent",
        "  - [x] child",
        "    - [x] grandchild",
        "  - [x] done child",
        "- [ ] sibling",
      }, get_lines())
    end)

    it("unchecks every descendant when unchecking a parent", function()
      set_lines({ "- [x] parent", "  - [x] child", "  - [X] upper" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [ ] parent", "  - [ ] child", "  - [ ] upper" }, get_lines())
    end)

    it("looks through list items without a checkbox", function()
      set_lines({ "- [ ] parent", "  - notes", "    - [ ] nested task" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [x] parent", "  - notes", "    - [x] nested task" }, get_lines())
    end)

    it("leaves custom states and their subtrees alone", function()
      set_lines({ "- [ ] parent", "  - [-] cancelled", "    - [ ] under cancelled", "  - [ ] open" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [x] parent", "  - [-] cancelled", "    - [ ] under cancelled", "  - [x] open" }, get_lines())
    end)

    it("does not push state down when the toggle only added a checkbox", function()
      set_lines({ "- parent", "  - [x] child" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [ ] parent", "  - [x] child" }, get_lines())
    end)

    it("works with ordered and letter lists", function()
      set_lines({ "1. [ ] parent", "   a. [ ] child", "   b) [ ] other" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "1. [x] parent", "   a. [x] child", "   b) [x] other" }, get_lines())
    end)

    it("skips tasks inside fenced code blocks", function()
      set_lines({ "- [ ] parent", "  ```", "  - [ ] example", "  ```", "  - [ ] child" })
      list.toggle_checkbox_on_line(1)
      assert.are.same({ "- [x] parent", "  ```", "  - [ ] example", "  ```", "  - [x] child" }, get_lines())
    end)
  end)

  describe("upward", function()
    it("does not count HTML-block tasks towards parent completion", function()
      set_lines({ "- [ ] parent", "  <div>", "  - [ ] HTML example", "  </div>", "", "  - [ ] real child" })
      list.toggle_checkbox_on_line(6)
      assert.are.same(
        { "- [x] parent", "  <div>", "  - [ ] HTML example", "  </div>", "", "  - [x] real child" },
        get_lines()
      )
    end)

    it("checks the parent chain when the last open child is checked", function()
      set_lines({
        "- [ ] grandparent",
        "  - [ ] parent",
        "    - [x] done",
        "    - [ ] last",
        "  - [x] aunt",
      })
      list.toggle_checkbox_on_line(4)
      assert.are.same({
        "- [x] grandparent",
        "  - [x] parent",
        "    - [x] done",
        "    - [x] last",
        "  - [x] aunt",
      }, get_lines())
    end)

    it("leaves the parent open while other children are open", function()
      set_lines({ "- [ ] parent", "  - [ ] one", "  - [ ] two" })
      list.toggle_checkbox_on_line(2)
      assert.are.same({ "- [ ] parent", "  - [x] one", "  - [ ] two" }, get_lines())
    end)

    it("unchecks checked ancestors when a child is unchecked", function()
      set_lines({ "- [x] grandparent", "  - [X] parent", "    - [x] child" })
      list.toggle_checkbox_on_line(3)
      assert.are.same({ "- [ ] grandparent", "  - [ ] parent", "    - [ ] child" }, get_lines())
    end)

    it("ignores custom-state children when deciding the parent state", function()
      set_lines({ "- [ ] parent", "  - [-] cancelled", "  - [ ] last" })
      list.toggle_checkbox_on_line(3)
      assert.are.same({ "- [x] parent", "  - [-] cancelled", "  - [x] last" }, get_lines())
    end)

    it("does not rewrite a custom-state parent", function()
      set_lines({ "- [ ] grandparent", "  - [-] parent", "    - [ ] child" })
      list.toggle_checkbox_on_line(3)
      assert.are.same({ "- [ ] grandparent", "  - [-] parent", "    - [x] child" }, get_lines())
    end)

    it("looks through list items without a checkbox", function()
      set_lines({ "- [ ] parent", "  - notes", "    - [ ] only task" })
      list.toggle_checkbox_on_line(3)
      assert.are.same({ "- [x] parent", "  - notes", "    - [x] only task" }, get_lines())
    end)

    it("reopens a checked parent when a new checkbox is added under it", function()
      set_lines({ "- [x] parent", "  - [x] done", "  - new item" })
      list.toggle_checkbox_on_line(3)
      assert.are.same({ "- [ ] parent", "  - [x] done", "  - [ ] new item" }, get_lines())
    end)
  end)

  describe("entry points", function()
    it("syncs from the insert mode toggle", function()
      set_lines({ "- [ ] parent", "  - [ ] child" })
      vim.api.nvim_win_set_cursor(0, { 2, 8 })
      list.toggle_checkbox_insert()
      assert.are.same({ "- [x] parent", "  - [x] child" }, get_lines())
      assert.are.same({ 2, 8 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("keeps selected items at their toggled state in a visual range", function()
      set_lines({ "- [ ] parent", "  - [x] selected child", "  - [ ] other child" })
      vim.cmd("normal! ggVj")
      list.toggle_checkbox_range()
      -- parent pushes [x] to the unselected child; the selected child toggles itself to [ ],
      -- so the parent ends up open again
      assert.are.same({ "- [ ] parent", "  - [ ] selected child", "  - [x] other child" }, get_lines())
    end)

    it("adds completion timestamps to synced items", function()
      markdown_plus.config.list.checkbox_completion = {
        enabled = true,
        format = "emoji",
        date_format = "%Y-%m-%d",
        remove_on_uncheck = true,
        update_existing = true,
      }
      set_lines({ "- [ ] parent", "  - [ ] child" })
      list.toggle_checkbox_on_line(2)
      local lines = get_lines()
      assert.is_not_nil(lines[1]:match("^%- %[x%] parent ✅ %d%d%d%d%-%d%d%-%d%d$"))
      assert.is_not_nil(lines[2]:match("^  %- %[x%] child ✅ %d%d%d%d%-%d%d%-%d%d$"))
    end)
  end)

  describe("plan", function()
    it("returns updates sorted by row and skips unchanged items", function()
      local updates = checkbox_sync.plan({
        "- [ ] parent",
        "  - [x] toggled",
        "  - [x] sibling",
      }, { { row = 2 } })
      assert.are.same({ { row = 1, state = "x" } }, updates)
    end)

    it("returns nothing for a row that is not a list item", function()
      assert.are.same({}, checkbox_sync.plan({ "text" }, { { row = 1 } }))
    end)
  end)
end)
