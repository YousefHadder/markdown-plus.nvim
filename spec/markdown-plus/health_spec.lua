---Test suite for health check module
---Tests configuration validation, version checks, and diagnostics
---@diagnostic disable: undefined-field
local health_module = require("markdown-plus.health")

describe("health check", function()
  before_each(function()
    -- Clean up global config before each test
    vim.g.markdown_plus = nil
    vim.g.loaded_markdown_plus = nil
    vim.g.loaded_vim_markdown = nil
  end)

  after_each(function()
    -- Clean up global config
    vim.g.markdown_plus = nil
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
      vim.g.markdown_plus = {}

      local success = pcall(function()
        health_module.check()
      end)
      assert.is_true(success, "Health check should work with minimal config")
    end)

    it("runs with full configuration", function()
      vim.g.markdown_plus = {
        enabled = true,
        features = {
          list_management = true,
          headers = true,
          text_formatting = true,
          links = true,
          quote = true,
          table = true,
        },
        filetypes = { "markdown", "md" },
        default_keymaps = true,
      }

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
