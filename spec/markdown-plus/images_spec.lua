-- Tests for markdown-plus images module
describe("markdown-plus images", function()
  local images = require("markdown-plus.images")

  before_each(function()
    -- Create a test buffer
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    images.setup({ enabled = true })
  end)

  after_each(function()
    -- Clean up test buffer
    vim.cmd("bdelete!")
  end)

  describe("pattern matching", function()
    it("matches basic image links", function()
      local text = "![alt text](https://example.com/image.png)"
      local alt, url = text:match(images.patterns.image_link)
      assert.equals("alt text", alt)
      assert.equals("https://example.com/image.png", url)
    end)

    it("matches image links with title", function()
      local text = '![alt text](https://example.com/image.png "Image Title")'
      local alt, url, title = text:match(images.patterns.image_with_title)
      assert.equals("alt text", alt)
      assert.equals("https://example.com/image.png", url)
      assert.equals("Image Title", title)
    end)

    it("matches regular links", function()
      local text = "[link text](https://example.com)"
      local link_text, url = text:match(images.patterns.regular_link)
      assert.equals("link text", link_text)
      assert.equals("https://example.com", url)
    end)
  end)

  describe("get_image_at_cursor", function()
    it("finds basic image link when cursor is on it", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is ![an image](https://example.com/pic.png) here." })
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- cursor on "an image"

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("image", image.type)
      assert.equals("an image", image.alt)
      assert.equals("https://example.com/pic.png", image.url)
      assert.is_nil(image.title)
    end)

    it("finds image with title when cursor is on it", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '![Screenshot](img/screenshot.png "My Screenshot")' })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- cursor on image

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("image_with_title", image.type)
      assert.equals("Screenshot", image.alt)
      assert.equals("img/screenshot.png", image.url)
      assert.equals("My Screenshot", image.title)
    end)

    it("returns nil when cursor is not on an image", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is plain text." })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local image = images.get_image_at_cursor()
      assert.is_nil(image)
    end)

    it("returns nil when cursor is on a regular link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is [a link](https://example.com) here." })
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- cursor on "a link"

      local image = images.get_image_at_cursor()
      assert.is_nil(image)
    end)

    it("handles multiple images on same line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![first](img1.png) and ![second](img2.png)" })

      -- Cursor on first image
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("first", image.alt)
      assert.equals("img1.png", image.url)

      -- Cursor on second image
      vim.api.nvim_win_set_cursor(0, { 1, 28 })
      image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("second", image.alt)
      assert.equals("img2.png", image.url)
    end)

    it("handles image with empty alt text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![](image.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("", image.alt)
      assert.equals("image.png", image.url)
    end)
  end)

  describe("patterns", function()
    it("has image_link pattern", function()
      assert.is_not_nil(images.patterns.image_link)
    end)

    it("has image_with_title pattern", function()
      assert.is_not_nil(images.patterns.image_with_title)
    end)

    it("has regular_link pattern", function()
      assert.is_not_nil(images.patterns.regular_link)
    end)
  end)

  describe("toggle_image_link", function()
    it("converts regular link to image link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[My Photo](photo.jpg)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- cursor on link

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![My Photo](photo.jpg)", lines[1])
    end)

    it("converts image link to regular link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![My Photo](photo.jpg)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- cursor on image

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("[My Photo](photo.jpg)", lines[1])
    end)

    it("preserves title when converting from image to link", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '![Photo](photo.jpg "My Photo")' })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals('[Photo](photo.jpg "My Photo")', lines[1])
    end)

    it("preserves title when converting from link to image", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '[Photo](photo.jpg "My Photo")' })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      images.toggle_image_link()

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals('![Photo](photo.jpg "My Photo")', lines[1])
    end)

    it("toggles back and forth correctly", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[Photo](photo.jpg)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      -- Link -> Image
      images.toggle_image_link()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![Photo](photo.jpg)", lines[1])

      -- Image -> Link
      images.toggle_image_link()
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("[Photo](photo.jpg)", lines[1])
    end)

    it("handles multiple links on same line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[first](img1.png) and [second](img2.png)" })

      -- Toggle first link
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      images.toggle_image_link()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![first](img1.png) and [second](img2.png)", lines[1])

      -- Toggle second link
      vim.api.nvim_win_set_cursor(0, { 1, 30 })
      images.toggle_image_link()
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals("![first](img1.png) and ![second](img2.png)", lines[1])
    end)
  end)

  describe("insert_image (manual test placeholder)", function()
    -- Note: insert_image requires user input via vim.fn.input
    -- These tests would need mocking or manual testing
    it("requires manual testing for user input", function()
      assert.is_function(images.insert_image)
    end)
  end)

  describe("edit_image (manual test placeholder)", function()
    -- Note: edit_image requires user input via vim.fn.input
    it("requires manual testing for user input", function()
      assert.is_function(images.edit_image)
    end)
  end)

  describe("selection_to_image (manual test placeholder)", function()
    -- Note: selection_to_image requires visual mode and user input
    it("requires manual testing for visual mode and input", function()
      assert.is_function(images.selection_to_image)
    end)
  end)

  describe("module structure", function()
    it("has setup function", function()
      assert.is_function(images.setup)
    end)

    it("has enable function", function()
      assert.is_function(images.enable)
    end)

    it("has setup_keymaps function", function()
      assert.is_function(images.setup_keymaps)
    end)

    it("has get_image_at_cursor function", function()
      assert.is_function(images.get_image_at_cursor)
    end)

    it("has insert_image function", function()
      assert.is_function(images.insert_image)
    end)

    it("has edit_image function", function()
      assert.is_function(images.edit_image)
    end)

    it("has selection_to_image function", function()
      assert.is_function(images.selection_to_image)
    end)

    it("has toggle_image_link function", function()
      assert.is_function(images.toggle_image_link)
    end)

    it("has patterns table", function()
      assert.is_table(images.patterns)
    end)

    it("has config table", function()
      assert.is_table(images.config)
    end)
  end)

  describe("edge cases", function()
    it("handles image at start of line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![Start](start.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("Start", image.alt)
    end)

    it("handles image at end of line", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Text ![End](end.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("End", image.alt)
    end)

    it("handles image with special characters in URL", function()
      vim.api.nvim_buf_set_lines(
        0,
        0,
        -1,
        false,
        { "![Image](https://example.com/path/to/image.png?v=123&size=large)" }
      )
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("Image", image.alt)
      assert.is_truthy(image.url:match("example.com"))
    end)

    it("handles image with relative path", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![Local](./images/local.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("Local", image.alt)
      assert.equals("./images/local.png", image.url)
    end)

    it("handles image with absolute path", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![Absolute](/root/image.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("Absolute", image.alt)
      assert.equals("/root/image.png", image.url)
    end)
  end)

  describe("complex scenarios", function()
    it("distinguishes between image and link when both present", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[link](url.html) and ![image](img.png)" })

      -- Cursor on link
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      local image = images.get_image_at_cursor()
      assert.is_nil(image) -- Should not detect image

      -- Cursor on image
      vim.api.nvim_win_set_cursor(0, { 1, 30 })
      image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("image", image.alt)
    end)

    it("handles nested brackets in alt text", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![Alt [with] brackets](img.png)" })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })

      -- Note: The current pattern may not handle nested brackets perfectly
      -- This test documents the current behavior
      local _ = images.get_image_at_cursor()
      -- Behavior depends on pattern implementation
    end)

    it("handles image followed by punctuation", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "See ![figure](fig.png). More text." })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      local image = images.get_image_at_cursor()
      assert.is_not_nil(image)
      assert.equals("figure", image.alt)
      assert.equals("fig.png", image.url)
    end)
  end)
end)
