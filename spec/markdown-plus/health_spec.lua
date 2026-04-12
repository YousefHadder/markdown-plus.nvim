---Test suite for health check module
---Tests configuration validation, version checks, and diagnostics
---@diagnostic disable: undefined-field
local health_module = require("markdown-plus.health")
local markdown_plus = require("markdown-plus")

describe("health check", function()
  before_each(function()
    -- Clean up global state before each test
    vim.g.loaded_markdown_plus = nil
    vim.g.loaded_vim_markdown = nil
  end)

  after_each(function()
    -- Clean up global state
    vim.g.loaded_markdown_plus = nil
    vim.g.loaded_vim_markdown = nil
  end)

  describe("check function", function()
    it("runs without errors", function()
      -- Basic test - just ensure check() doesn't throw errors
      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should run without errors")
    end)

    it("runs with minimal configuration", function()
      markdown_plus.setup({})

      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should work with minimal config")
    end)

    it("runs with full configuration", function()
      markdown_plus.setup({
        enabled = true,
        features = {
          list_management = true,
          headers_toc = true,
          text_formatting = true,
          links = true,
          quotes = true,
          table = true,
        },
        filetypes = { "markdown", "md" },
      })

      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should work with full config")
    end)

    it("handles vim-markdown plugin presence", function()
      vim.g.loaded_vim_markdown = 1

      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should detect vim-markdown")

      vim.g.loaded_vim_markdown = nil
    end)

    it("handles when plugin is already loaded", function()
      vim.g.loaded_markdown_plus = 1

      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should work when plugin loaded")

      vim.g.loaded_markdown_plus = nil
    end)

    it("warns when deprecated vim.g.markdown_plus config is present", function()
      local saved_warn = vim.health.warn
      local saved_global_config = vim.g.markdown_plus
      local warning_messages = {}

      vim.health.warn = function(msg, _)
        table.insert(warning_messages, msg)
      end

      vim.g.markdown_plus = { enabled = true }

      local success = pcall(function()
        health_module.check()
      end)

      vim.health.warn = saved_warn
      vim.g.markdown_plus = saved_global_config

      assert.is_true(success, "Health check should run with deprecated config present")

      local found_deprecation_warning = false
      for _, msg in ipairs(warning_messages) do
        if msg:match("vim%.g%.markdown_plus") then
          found_deprecation_warning = true
          break
        end
      end

      assert.is_true(found_deprecation_warning, "Expected warning for deprecated vim.g.markdown_plus configuration")
    end)

    it("warns when plugin is not loaded", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      vim.g.loaded_markdown_plus = nil

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "warn" and call.msg:find("not loaded") then
          found = true
        end
      end
      assert.is_true(found, "Expected warning about plugin not loaded")
    end)

    it("warns about deprecated vim.g.markdown_plus with v2.0 message", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      vim.g.markdown_plus = {}

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start
      vim.g.markdown_plus = nil

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "warn" and call.msg:find("v2%.0") then
          found = true
        end
      end
      assert.is_true(found, "Expected warning mentioning v2.0 for deprecated vim.g.markdown_plus")
    end)

    it("warns when no features are enabled", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      markdown_plus.setup({
        features = {
          list_management = false,
          headers_toc = false,
          text_formatting = false,
          links = false,
          quotes = false,
          table = false,
          footnotes = false,
          callouts = false,
          images = false,
          code_block = false,
          thematic_break = false,
          html_block_awareness = false,
        },
      })

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "warn" and call.msg:find("No features are enabled") then
          found = true
        end
      end
      assert.is_true(found, "Expected warning about no features enabled")
    end)

    it("shows info when keymaps are disabled", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      markdown_plus.setup({
        keymaps = { enabled = false },
      })

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "info" and call.msg:find("custom keymaps") then
          found = true
        end
      end
      assert.is_true(found, "Expected info message about custom keymaps when keymaps disabled")
    end)

    it("warns about vim-markdown conflict", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      vim.g.loaded_vim_markdown = 1

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start
      vim.g.loaded_vim_markdown = nil

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "warn" and call.msg:find("vim%-markdown") then
          found = true
        end
      end
      assert.is_true(found, "Expected warning about vim-markdown conflict")
    end)

    it("shows info when not in a markdown buffer", function()
      local health_calls = {}
      local orig_ok, orig_warn, orig_error, orig_info, orig_start =
        vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start
      vim.health.ok = function(msg)
        table.insert(health_calls, { type = "ok", msg = msg })
      end
      vim.health.warn = function(msg, ...)
        table.insert(health_calls, { type = "warn", msg = msg })
      end
      vim.health.error = function(msg, ...)
        table.insert(health_calls, { type = "error", msg = msg })
      end
      vim.health.info = function(msg, ...)
        table.insert(health_calls, { type = "info", msg = msg })
      end
      vim.health.start = function(msg)
        table.insert(health_calls, { type = "start", msg = msg })
      end

      vim.bo.filetype = ""

      health_module.check()

      vim.health.ok, vim.health.warn, vim.health.error, vim.health.info, vim.health.start =
        orig_ok, orig_warn, orig_error, orig_info, orig_start

      local found = false
      for _, call in ipairs(health_calls) do
        if call.type == "info" and call.msg:find("Not in markdown buffer") then
          found = true
        end
      end
      assert.is_true(found, "Expected info message about not being in a markdown buffer")
    end)
  end)

  describe("error handling", function()
    it("handles missing vim.health gracefully", function()
      local saved_health = vim.health
      vim.health = nil

      local success = pcall(function()
        health_module.check()
      end)

      vim.health = saved_health
      assert.is_true(success, "Should handle missing vim.health")
    end)

    it("handles missing vim.treesitter gracefully", function()
      local saved_ts = vim.treesitter
      vim.treesitter = nil

      local success = pcall(function()
        health_module.check()
      end)

      vim.treesitter = saved_ts
      assert.is_true(success, "Should handle missing vim.treesitter without throwing")
    end)

    it("handles treesitter get_parser error gracefully", function()
      local saved_ts = vim.treesitter
      vim.treesitter = {
        get_parser = function()
          error("no parser for markdown")
        end,
      }

      local success = pcall(function()
        health_module.check()
      end)

      vim.treesitter = saved_ts
      assert.is_true(success, "Should handle treesitter parser error without throwing")
    end)
  end)

  describe("module accessibility", function()
    it("exposes check function", function()
      assert.is_function(health_module.check, "Should expose check function")
    end)

    it("can be called multiple times", function()
      local success1 = pcall(function()
        health_module.check()
      end)

      local success2 = pcall(function()
        health_module.check()
      end)

      assert.is_true(success1, "First call should succeed")
      assert.is_true(success2, "Second call should succeed")
    end)
  end)
end)
