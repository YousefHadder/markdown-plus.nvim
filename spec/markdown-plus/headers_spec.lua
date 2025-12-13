---Test suite for markdown-plus.nvim headers and TOC functionality
---Tests header parsing, slug generation, TOC detection, and TOC generation
---@diagnostic disable: undefined-field
local headers = require("markdown-plus.headers")

describe("markdown-plus headers", function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_set_current_buf(buf)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("parse_header", function()
    it("parses markdown headers", function()
      local header = headers.parse_header("## Test Header")
      assert.is_not_nil(header)
      assert.are.equal(2, header.level)
      assert.are.equal("Test Header", header.text)
    end)

    it("returns nil for non-header lines", function()
      local header = headers.parse_header("Not a header")
      assert.is_nil(header)
    end)
  end)

  describe("generate_slug", function()
    it("generates valid slugs from header text", function()
      assert.are.equal("test-header", headers.generate_slug("Test Header"))
      assert.are.equal("hello-world", headers.generate_slug("Hello World"))
      assert.are.equal("with-code", headers.generate_slug("With `code`"))
    end)

    it("handles special characters", function()
      assert.are.equal("test--header", headers.generate_slug("Test & Header"))
      assert.are.equal("123-numbers", headers.generate_slug("123 Numbers"))
    end)
  end)

  describe("find_toc", function()
    it("finds TOC with markers and links", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Document",
        "<!-- TOC -->",
        "- [Header](#header)",
        "<!-- /TOC -->",
        "",
        "## Header",
      })

      local toc = headers.find_toc()
      assert.is_not_nil(toc)
      assert.are.equal(2, toc.start_line)
      assert.are.equal(4, toc.end_line)
    end)

    it("ignores markers without TOC links (documentation examples)", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Document",
        "You can add TOC with:",
        "<!-- TOC -->",
        "<!-- /TOC -->",
        "",
        "## Header",
      })

      local toc = headers.find_toc()
      -- Should not find TOC because there are no actual links
      assert.is_nil(toc)
    end)

    it("finds legacy TOC without markers", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Document",
        "## Table of Contents",
        "- [Header](#header)",
        "",
        "## Header",
      })

      local toc = headers.find_toc()
      assert.is_not_nil(toc)
    end)

    it("ignores 'Table of Contents' headers without links", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Document",
        "## Table of Contents",
        "",
        "This section will contain the TOC.",
        "",
        "## Header",
      })

      local toc = headers.find_toc()
      -- Should not find TOC because there are no actual links
      assert.is_nil(toc)
    end)

    it("returns nil when no TOC exists", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Document",
        "## Header",
        "Content",
      })

      local toc = headers.find_toc()
      assert.is_nil(toc)
    end)

    it("handles end-of-TOC detection with any header level", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "<!-- TOC -->",
        "- [H1](#h1)",
        "- [H2](#h2)",
        "<!-- /TOC -->",
        "",
        "# H1",
      })

      local toc = headers.find_toc()
      assert.is_not_nil(toc)
      assert.are.equal(4, toc.end_line)
    end)
  end)

  describe("generate_toc", function()
    it("generates TOC for document with headers", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "",
        "## Section 1",
        "Content",
        "",
        "## Section 2",
        "More content",
      })

      headers.generate_toc()

      -- Check that TOC was inserted
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local has_toc_marker = false
      for _, line in ipairs(lines) do
        if line:match("<!%-%- TOC %-%->") then
          has_toc_marker = true
          break
        end
      end
      assert.is_true(has_toc_marker)
    end)

    it("does not create duplicate TOC", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "<!-- TOC -->",
        "- [Section](#section)",
        "<!-- /TOC -->",
        "",
        "## Section",
      })

      headers.generate_toc()

      -- Should not create a second TOC
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local toc_count = 0
      for _, line in ipairs(lines) do
        if line:match("<!%-%- TOC %-%->") then
          toc_count = toc_count + 1
        end
      end
      assert.are.equal(1, toc_count)
    end)

    it("respects initial_depth config (depth=2)", function()
      local toc_mod = require("markdown-plus.headers.toc")
      toc_mod.set_config({ toc = { initial_depth = 2 } })

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "",
        "## Section 1",
        "### Subsection 1.1",
        "#### Deep 1.1.1",
        "## Section 2",
        "### Subsection 2.1",
      })

      headers.generate_toc()

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      -- Find TOC section and check its contents
      local in_toc = false
      local toc_has_section = false
      local toc_has_subsection = false
      local toc_has_deep = false

      for _, line in ipairs(lines) do
        if line:match("<!%-%- TOC %-%->") then
          in_toc = true
        elseif line:match("<!%-%- /TOC %-%->") then
          in_toc = false
        elseif in_toc and line:match("^%s*%-%s+%[") then
          -- This is a TOC entry
          if line:match("Section 1") or line:match("Section 2") then
            toc_has_section = true
          end
          if line:match("Subsection") then
            toc_has_subsection = true
          end
          if line:match("Deep") then
            toc_has_deep = true
          end
        end
      end

      assert.is_true(toc_has_section)
      assert.is_false(toc_has_subsection) -- Should not include H3 in TOC
      assert.is_false(toc_has_deep) -- Should not include H4 in TOC
    end)

    it("respects initial_depth config (depth=3)", function()
      local toc_mod = require("markdown-plus.headers.toc")
      toc_mod.set_config({ toc = { initial_depth = 3 } })

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "",
        "## Section 1",
        "### Subsection 1.1",
        "#### Deep 1.1.1",
        "## Section 2",
      })

      headers.generate_toc()

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      -- Find TOC section and check its contents
      local in_toc = false
      local toc_has_section = false
      local toc_has_subsection = false
      local toc_has_deep = false

      for _, line in ipairs(lines) do
        if line:match("<!%-%- TOC %-%->") then
          in_toc = true
        elseif line:match("<!%-%- /TOC %-%->") then
          in_toc = false
        elseif in_toc and line:match("^%s*%-%s+%[") then
          -- This is a TOC entry
          if line:match("Section 1") then
            toc_has_section = true
          end
          if line:match("Subsection") then
            toc_has_subsection = true
          end
          if line:match("Deep") then
            toc_has_deep = true
          end
        end
      end

      assert.is_true(toc_has_section)
      assert.is_true(toc_has_subsection) -- Should include H3 in TOC
      assert.is_false(toc_has_deep) -- Should not include H4 in TOC
    end)

    it("update_toc respects initial_depth config", function()
      local toc_mod = require("markdown-plus.headers.toc")
      toc_mod.set_config({ toc = { initial_depth = 2 } })

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "<!-- TOC -->",
        "- [Old Entry](#old)",
        "<!-- /TOC -->",
        "",
        "## Section 1",
        "### Subsection 1.1",
        "## Section 2",
      })

      headers.update_toc()

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      -- Find TOC section and check its contents
      local in_toc = false
      local toc_has_section1 = false
      local toc_has_section2 = false
      local toc_has_subsection = false

      for _, line in ipairs(lines) do
        if line:match("<!%-%- TOC %-%->") then
          in_toc = true
        elseif line:match("<!%-%- /TOC %-%->") then
          in_toc = false
        elseif in_toc and line:match("^%s*%-%s+%[") then
          -- This is a TOC entry
          if line:match("Section 1") then
            toc_has_section1 = true
          end
          if line:match("Section 2") then
            toc_has_section2 = true
          end
          if line:match("Subsection") then
            toc_has_subsection = true
          end
        end
      end

      assert.is_true(toc_has_section1)
      assert.is_true(toc_has_section2)
      assert.is_false(toc_has_subsection) -- Should not include H3 in TOC with depth=2
    end)
  end)

  describe("open_toc_window", function()
    -- Helper function to cleanup TOC windows/buffers
    local function cleanup_toc_window()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local win_buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_is_valid(win_buf) then
            local name = vim.api.nvim_buf_get_name(win_buf)
            if name:match("TOC:") then
              vim.api.nvim_win_close(win, true)
            end
          end
        end
      end
    end

    it("opens TOC window with headers", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Main Title",
        "Some content",
        "## Section 1",
        "More content",
        "### Subsection",
        "## Section 2",
      })

      headers.open_toc_window()

      -- Check that a window was created
      local wins = vim.api.nvim_list_wins()
      local toc_win = nil
      for _, win in ipairs(wins) do
        local win_buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(win_buf)
        if name:match("TOC:") then
          toc_win = win
          break
        end
      end

      assert.is_not_nil(toc_win)

      -- Clean up
      cleanup_toc_window()
    end)

    it("toggles TOC window on/off", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Header 1",
        "## Header 2",
      })

      -- Open TOC
      headers.open_toc_window()
      local wins_after_open = #vim.api.nvim_list_wins()

      -- Toggle (close)
      headers.open_toc_window()
      local wins_after_close = #vim.api.nvim_list_wins()

      -- Should have closed the window
      assert.is_true(wins_after_close < wins_after_open)
    end)

    it("shows warning when no headers found", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Just plain text",
        "No headers here",
      })

      -- Capture notification
      local notified = false
      local notified_level = nil
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match("No headers") then
          notified = true
          notified_level = level
        end
      end

      headers.open_toc_window()

      vim.notify = orig_notify
      assert.is_true(notified)
      assert.are.equal(vim.log.levels.WARN, notified_level)
    end)

    it("displays headers at initial depth 2", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# H1",
        "## H2",
        "### H3",
        "#### H4",
      })

      headers.open_toc_window()

      -- Find TOC buffer
      local toc_buf = nil
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) then
          local name = vim.api.nvim_buf_get_name(b)
          if name:match("TOC:") then
            toc_buf = b
            break
          end
        end
      end

      if toc_buf then
        local lines = vim.api.nvim_buf_get_lines(toc_buf, 0, -1, false)
        -- Should show H1 and H2, but not H3 and H4 initially
        local has_h1 = false
        local has_h2 = false
        local has_h3 = false

        for _, line in ipairs(lines) do
          if line:match("%[H1%]") then
            has_h1 = true
          end
          if line:match("%[H2%]") then
            has_h2 = true
          end
          if line:match("%[H3%]") then
            has_h3 = true
          end
        end

        assert.is_true(has_h1)
        assert.is_true(has_h2)
        assert.is_false(has_h3) -- Should not show initially (depth > 2)

        -- Clean up
        cleanup_toc_window()
      end
    end)
  end)

  describe("get_all_headers", function()
    it("returns all headers from buffer", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Header 1",
        "Content",
        "## Header 2",
        "### Header 3",
      })

      local all_headers = headers.get_all_headers()
      assert.are.equal(3, #all_headers)
      assert.are.equal(1, all_headers[1].level)
      assert.are.equal(2, all_headers[2].level)
      assert.are.equal(3, all_headers[3].level)
    end)

    it("filters headers in code blocks", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# Real Header",
        "```",
        "# Not a header",
        "```",
        "## Another Real Header",
      })

      local all_headers = headers.get_all_headers()
      assert.are.equal(2, #all_headers)
      assert.are.equal("Real Header", all_headers[1].text)
      assert.are.equal("Another Real Header", all_headers[2].text)
    end)
  end)
end)
