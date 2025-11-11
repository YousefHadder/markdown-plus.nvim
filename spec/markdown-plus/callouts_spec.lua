-- Tests for markdown-plus callouts module
describe("markdown-plus callouts", function()
  local callouts = require("markdown-plus.callouts")
  local utils = require("markdown-plus.utils")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    callouts.setup({
      enabled = true,
      features = {
        callouts = true,
      },
      keymaps = {
        enabled = true,
      },
      filetypes = { "markdown" },
      callouts = {
        default_type = "NOTE",
        custom_types = {},
      },
    })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("is_valid_callout_type", function()
    it("validates standard GFM callout types", function()
      assert.is_true(callouts.is_valid_callout_type("NOTE"))
      assert.is_true(callouts.is_valid_callout_type("TIP"))
      assert.is_true(callouts.is_valid_callout_type("IMPORTANT"))
      assert.is_true(callouts.is_valid_callout_type("WARNING"))
      assert.is_true(callouts.is_valid_callout_type("CAUTION"))
    end)

    it("rejects invalid callout types", function()
      assert.is_false(callouts.is_valid_callout_type("INVALID"))
      assert.is_false(callouts.is_valid_callout_type("note"))
      assert.is_false(callouts.is_valid_callout_type(""))
    end)

    it("accepts custom callout types", function()
      callouts.setup({
        enabled = true,
        features = { callouts = true },
        keymaps = { enabled = true },
        filetypes = { "markdown" },
        callouts = {
          default_type = "NOTE",
          custom_types = { "DANGER", "SUCCESS" },
        },
      })
      assert.is_true(callouts.is_valid_callout_type("DANGER"))
      assert.is_true(callouts.is_valid_callout_type("SUCCESS"))
    end)
  end)

  describe("get_callout_at_cursor", function()
    it("detects callout when cursor is on first line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!NOTE]",
        "> This is a note",
        "> Second line",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal("NOTE", info.type)
      assert.are.equal(1, info.start_line)
      assert.are.equal(3, info.end_line)
    end)

    it("detects callout when cursor is on content line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!WARNING]",
        "> Warning content",
        "> More content",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 5 })
      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal("WARNING", info.type)
      assert.are.equal(1, info.start_line)
      assert.are.equal(3, info.end_line)
    end)

    it("returns nil when not in a callout", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Regular text",
        "> Regular blockquote",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local info = callouts.get_callout_at_cursor()
      assert.is_nil(info)
    end)

    it("returns nil when in regular blockquote", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> Regular blockquote",
        "> Not a callout",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local info = callouts.get_callout_at_cursor()
      assert.is_nil(info)
    end)

    it("detects multi-line callout correctly", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!TIP]",
        "> Line 1",
        "> Line 2",
        "> Line 3",
        "> Line 4",
        "Regular text",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal("TIP", info.type)
      assert.are.equal(1, info.start_line)
      assert.are.equal(5, info.end_line)
    end)
  end)

  describe("insert_callout", function()
    it("inserts callout on empty line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      callouts.insert_callout("NOTE")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("> [!NOTE]", lines[1])
      assert.are.equal("> ", lines[2])
    end)

    it("inserts callout above non-empty line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Existing content" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      callouts.insert_callout("WARNING")
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("> [!WARNING]", lines[1])
      assert.are.equal("> ", lines[2])
      assert.are.equal("Existing content", lines[3])
    end)

    it("uses default type when not specified", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      callouts.insert_callout()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are.equal("> [!NOTE]", lines[1])
    end)
  end)

  describe("toggle_callout_type", function()
    it("cycles through callout types", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!NOTE]",
        "> Content",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- NOTE -> TIP
      callouts.toggle_callout_type()
      local line = utils.get_line(1)
      assert.are.equal("> [!TIP]", line)

      -- TIP -> IMPORTANT
      callouts.toggle_callout_type()
      line = utils.get_line(1)
      assert.are.equal("> [!IMPORTANT]", line)

      -- IMPORTANT -> WARNING
      callouts.toggle_callout_type()
      line = utils.get_line(1)
      assert.are.equal("> [!WARNING]", line)

      -- WARNING -> CAUTION
      callouts.toggle_callout_type()
      line = utils.get_line(1)
      assert.are.equal("> [!CAUTION]", line)

      -- CAUTION -> NOTE (cycle back)
      callouts.toggle_callout_type()
      line = utils.get_line(1)
      assert.are.equal("> [!NOTE]", line)
    end)

    it("works when cursor is on content line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!WARNING]",
        "> Content line",
        "> Another line",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 5 })

      callouts.toggle_callout_type()
      local line = utils.get_line(1)
      assert.are.equal("> [!CAUTION]", line)
    end)
  end)

  describe("convert_to_blockquote", function()
    it("converts callout to regular blockquote", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!NOTE]",
        "> This is content",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      callouts.convert_to_blockquote()
      local line = utils.get_line(1)
      assert.are.equal(">", line)
    end)

    it("converts callout with content on first line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!WARNING] Some content",
        "> More content",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      callouts.convert_to_blockquote()
      local line = utils.get_line(1)
      assert.are.equal("> Some content", line)
    end)

    it("preserves indentation in blockquote", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "  > [!TIP]",
        "  > Content",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      callouts.convert_to_blockquote()
      local line = utils.get_line(1)
      assert.are.equal("  >", line)
    end)
  end)

  describe("edge cases", function()
    it("handles callout with no content lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!NOTE]",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal("NOTE", info.type)
      assert.are.equal(1, info.start_line)
      assert.are.equal(1, info.end_line)
    end)

    it("handles callout with empty quote lines", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!IMPORTANT]",
        ">",
        "> Content after empty line",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal("IMPORTANT", info.type)
    end)

    it("stops at non-blockquote line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "> [!CAUTION]",
        "> Line 1",
        "Regular text",
        "> Not part of callout",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local info = callouts.get_callout_at_cursor()
      assert.is_not_nil(info)
      assert.are.equal(1, info.start_line)
      assert.are.equal(2, info.end_line)
    end)
  end)

  describe("get_default_type", function()
    it("returns configured default type", function()
      local default = callouts.get_default_type()
      assert.are.equal("NOTE", default)
    end)

    it("returns configured custom default", function()
      callouts.setup({
        enabled = true,
        features = { callouts = true },
        keymaps = { enabled = true },
        filetypes = { "markdown" },
        callouts = {
          default_type = "WARNING",
          custom_types = {},
        },
      })
      local default = callouts.get_default_type()
      assert.are.equal("WARNING", default)
    end)
  end)
end)
