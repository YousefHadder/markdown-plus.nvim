-- Tests for markdown-plus images insertion, editing, and toggling
describe("markdown-plus images", function()
  local images = require("markdown-plus.images")
  local mocks = require("spec.helpers.mocks")
  local notify_spy, input_spy

  before_each(function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    notify_spy = mocks.mock_notify()
    images.setup({ enabled = true, keymaps = { enabled = true } })
  end)

  after_each(function()
    notify_spy.restore()
    if input_spy then
      input_spy.restore()
    end
    vim.cmd("bdelete!")
  end)

  describe("insert_image", function()
    it("inserts image with alt, url, and title", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ "Alt text", "https://img.png", "My title" })

      images.insert_image()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals('![Alt text](https://img.png "My title")', lines[1])
    end)

    it("does nothing when alt text is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "original" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ nil })

      images.insert_image()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("original", lines[1])
    end)

    it("does nothing when url is cancelled", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "original" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      input_spy = mocks.mock_input({ "alt", nil })

      images.insert_image()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("original", lines[1])
    end)
  end)

  describe("edit_image", function()
    it("notifies when no image under cursor", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "just plain text here" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      images.edit_image()

      assert.equals(1, #notify_spy.calls)
      assert.is_truthy(notify_spy.calls[1].msg:find("No image under cursor"))
      assert.equals(vim.log.levels.WARN, notify_spy.calls[1].level)
    end)

    it("updates image values", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![old](http://old.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      input_spy = mocks.mock_input({ "new alt", "http://new.png", "" })

      images.edit_image()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![new alt](http://new.png)", lines[1])
    end)
  end)

  describe("toggle_image_link", function()
    it("converts image to regular link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![alt](url)" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("[alt](url)", lines[1])
    end)

    it("converts regular link to image", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[text](url)" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![text](url)", lines[1])
    end)
  end)
end)
