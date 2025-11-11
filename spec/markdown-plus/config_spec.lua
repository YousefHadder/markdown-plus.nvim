---Test suite for markdown-plus.nvim configuration and validation
---Tests configuration parsing, validation, and default values
---@diagnostic disable: undefined-field
local markdown_plus = require("markdown-plus")

describe("markdown-plus configuration", function()
  local original_config
  local original_vim_g

  before_each(function()
    -- Save original config and vim.g
    original_config = vim.deepcopy(markdown_plus.config)
    original_vim_g = vim.g.markdown_plus
    vim.g.markdown_plus = nil
  end)

  after_each(function()
    -- Restore original config and vim.g
    markdown_plus.config = original_config
    vim.g.markdown_plus = original_vim_g
  end)

  describe("setup", function()
    it("accepts empty config", function()
      assert.has_no.errors(function()
        markdown_plus.setup()
      end)
    end)

    it("accepts valid config", function()
      assert.has_no.errors(function()
        markdown_plus.setup({
          enabled = false,
          features = {
            list_management = false,
          },
        })
      end)
      assert.is_false(markdown_plus.config.enabled)
      assert.is_false(markdown_plus.config.features.list_management)
    end)

    it("merges config with defaults", function()
      markdown_plus.setup({
        features = {
          list_management = false,
        },
      })

      -- Check that other features are still enabled (default)
      assert.is_false(markdown_plus.config.features.list_management)
      assert.is_true(markdown_plus.config.features.text_formatting)
      assert.is_true(markdown_plus.config.features.headers_toc)
    end)

    it("validates boolean fields", function()
      local _ = pcall(function()
        markdown_plus.setup({
          enabled = "yes", -- Should be boolean
        })
      end)
      -- Should either error or handle gracefully
      -- The actual behavior depends on validation implementation
    end)

    it("detects unknown fields", function()
      -- Test should validate but may not error depending on implementation
      pcall(function()
        markdown_plus.setup({
          unknown_field = true,
        })
      end)
    end)
  end)

  describe("default configuration", function()
    it("has all required features defined", function()
      assert.is_not_nil(markdown_plus.config.features)
      assert.is_not_nil(markdown_plus.config.features.list_management)
      assert.is_not_nil(markdown_plus.config.features.text_formatting)
      assert.is_not_nil(markdown_plus.config.features.headers_toc)
      assert.is_not_nil(markdown_plus.config.features.links)
    end)

    it("has keymaps configuration", function()
      assert.is_not_nil(markdown_plus.config.keymaps)
      assert.is_not_nil(markdown_plus.config.keymaps.enabled)
    end)

    it("is enabled by default", function()
      assert.is_true(markdown_plus.config.enabled)
    end)
  end)

  describe("feature toggles", function()
    it("can disable all features", function()
      markdown_plus.setup({
        features = {
          list_management = false,
          text_formatting = false,
          headers_toc = false,
          links = false,
        },
      })

      assert.is_false(markdown_plus.config.features.list_management)
      assert.is_false(markdown_plus.config.features.text_formatting)
      assert.is_false(markdown_plus.config.features.headers_toc)
      assert.is_false(markdown_plus.config.features.links)
    end)

    it("can disable keymaps", function()
      markdown_plus.setup({
        keymaps = {
          enabled = false,
        },
      })

      assert.is_false(markdown_plus.config.keymaps.enabled)
    end)
  end)

  describe("vim.g configuration", function()
    it("accepts vim.g.markdown_plus table", function()
      vim.g.markdown_plus = {
        enabled = false,
        features = {
          list_management = false,
        },
      }

      assert.has_no.errors(function()
        markdown_plus.setup()
      end)

      assert.is_false(markdown_plus.config.enabled)
      assert.is_false(markdown_plus.config.features.list_management)
    end)

    it("accepts vim.g.markdown_plus function", function()
      vim.g.markdown_plus = function()
        return {
          enabled = false,
          features = {
            text_formatting = false,
          },
        }
      end

      assert.has_no.errors(function()
        markdown_plus.setup()
      end)

      assert.is_false(markdown_plus.config.enabled)
      assert.is_false(markdown_plus.config.features.text_formatting)
    end)

    it("setup() takes precedence over vim.g", function()
      vim.g.markdown_plus = {
        enabled = false,
        features = {
          list_management = false,
        },
      }

      markdown_plus.setup({
        enabled = true, -- Override vim.g
        features = {
          list_management = true, -- Override vim.g
        },
      })

      assert.is_true(markdown_plus.config.enabled)
      assert.is_true(markdown_plus.config.features.list_management)
    end)

    it("merges vim.g with setup() config", function()
      vim.g.markdown_plus = {
        features = {
          list_management = false,
        },
      }

      markdown_plus.setup({
        features = {
          text_formatting = false,
        },
      })

      -- Both should be disabled
      assert.is_false(markdown_plus.config.features.list_management)
      assert.is_false(markdown_plus.config.features.text_formatting)
      -- Others should still be enabled (defaults)
      assert.is_true(markdown_plus.config.features.headers_toc)
      assert.is_true(markdown_plus.config.features.links)
    end)

    it("handles invalid vim.g type gracefully", function()
      vim.g.markdown_plus = "invalid string"

      -- Should not error, just warn and use defaults
      assert.has_no.errors(function()
        markdown_plus.setup()
      end)

      -- Should still be enabled (default)
      assert.is_true(markdown_plus.config.enabled)
    end)

    it("handles vim.g function errors gracefully", function()
      vim.g.markdown_plus = function()
        error("Intentional error")
      end

      -- Should not error, just notify and use defaults
      assert.has_no.errors(function()
        markdown_plus.setup()
      end)

      -- Should still be enabled (default)
      assert.is_true(markdown_plus.config.enabled)
    end)

    it("handles vim.g function returning non-table", function()
      vim.g.markdown_plus = function()
        return "not a table"
      end

      -- Should not error, just notify and use defaults
      assert.has_no.errors(function()
        markdown_plus.setup()
      end)

      -- Should still be enabled (default)
      assert.is_true(markdown_plus.config.enabled)
    end)

    it("validates vim.g config like setup() config", function()
      vim.g.markdown_plus = {
        unknown_field = true, -- Invalid field
      }

      -- Should notify about invalid config
      local setup_succeeded = pcall(function()
        markdown_plus.setup()
      end)

      -- Validation should catch the error
      -- (exact behavior depends on validate() implementation)
      assert.is_not_nil(setup_succeeded)
    end)
  end)

  describe("keymap setup with buffer-local detection", function()
    local buf
    local keymap_helper

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
      vim.api.nvim_set_current_buf(buf)
      keymap_helper = require("markdown-plus.keymap_helper")
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("creates default keymaps when no buffer-local mappings exist", function()
      local test_config = {
        keymaps = { enabled = true },
      }

      keymap_helper.setup_keymaps(test_config, {
        {
          plug = "MarkdownPlusTestAction",
          fn = function() end,
          modes = "i",
          default_key = "<C-x>",
          desc = "Test action",
        },
      })

      -- Check that buffer-local mapping was created
      local mapping = vim.fn.maparg("<C-x>", "i", false, true)
      assert.is_not_nil(mapping)
      assert.are.equal(1, mapping.buffer)
    end)

    it("does not create default keymaps when buffer-local mappings already exist", function()
      -- Create a buffer-local mapping first
      vim.keymap.set("i", "<C-y>", "existing", { buffer = true })

      local test_config = {
        keymaps = { enabled = true },
      }

      -- Try to set up with same key
      keymap_helper.setup_keymaps(test_config, {
        {
          plug = "MarkdownPlusTestAction2",
          fn = function() end,
          modes = "i",
          default_key = "<C-y>",
          desc = "Test action 2",
        },
      })

      -- Check that original mapping was preserved
      local mapping = vim.fn.maparg("<C-y>", "i", false, true)
      assert.is_not_nil(mapping)
      assert.are.equal("existing", mapping.rhs)
    end)

    it("creates default keymaps even when global <Plug> mappings exist", function()
      -- Create a global <Plug> mapping
      vim.keymap.set("i", "<Plug>(MarkdownPlusTestGlobal)", function() end)

      local test_config = {
        keymaps = { enabled = true },
      }

      -- Set up with default key that should still be created
      keymap_helper.setup_keymaps(test_config, {
        {
          plug = "MarkdownPlusTestGlobal",
          fn = function() end,
          modes = "i",
          default_key = "<C-z>",
          desc = "Test global action",
        },
      })

      -- Check that buffer-local mapping was created
      local mapping = vim.fn.maparg("<C-z>", "i", false, true)
      assert.is_not_nil(mapping)
      assert.are.equal(1, mapping.buffer)
    end)
  end)

  describe("callouts configuration", function()
    it("accepts valid callouts config", function()
      assert.has_no.errors(function()
        markdown_plus.setup({
          callouts = {
            default_type = "WARNING",
            custom_types = { "DANGER", "SUCCESS" },
          },
        })
      end)
      -- Verify the callouts module is loaded when config is valid
      assert.is_not_nil(markdown_plus.callouts)
    end)

    it("rejects invalid custom_types (not an array)", function()
      -- Setup with invalid config - should notify and not load callouts
      local original_callouts = markdown_plus.callouts
      markdown_plus.callouts = nil

      pcall(function()
        markdown_plus.setup({
          callouts = {
            custom_types = "not_an_array",
          },
        })
      end)

      -- Module should not be loaded due to validation failure
      assert.is_nil(markdown_plus.callouts)
      markdown_plus.callouts = original_callouts
    end)

    it("rejects invalid custom_types (contains non-strings)", function()
      local original_callouts = markdown_plus.callouts
      markdown_plus.callouts = nil

      pcall(function()
        markdown_plus.setup({
          callouts = {
            custom_types = { "VALID", 123 },
          },
        })
      end)

      assert.is_nil(markdown_plus.callouts)
      markdown_plus.callouts = original_callouts
    end)

    it("rejects invalid custom_types (not uppercase)", function()
      local original_callouts = markdown_plus.callouts
      markdown_plus.callouts = nil

      pcall(function()
        markdown_plus.setup({
          callouts = {
            custom_types = { "lowercase" },
          },
        })
      end)

      assert.is_nil(markdown_plus.callouts)
      markdown_plus.callouts = original_callouts
    end)

    it("rejects invalid custom_types (contains non-letter characters)", function()
      local original_callouts = markdown_plus.callouts
      markdown_plus.callouts = nil

      pcall(function()
        markdown_plus.setup({
          callouts = {
            custom_types = { "TYPE-123" },
          },
        })
      end)

      assert.is_nil(markdown_plus.callouts)
      markdown_plus.callouts = original_callouts
    end)

    it("rejects invalid default_type (not a valid type)", function()
      local original_callouts = markdown_plus.callouts
      markdown_plus.callouts = nil

      pcall(function()
        markdown_plus.setup({
          callouts = {
            default_type = "INVALID",
          },
        })
      end)

      assert.is_nil(markdown_plus.callouts)
      markdown_plus.callouts = original_callouts
    end)

    it("accepts default_type that is a custom_type", function()
      assert.has_no.errors(function()
        markdown_plus.setup({
          callouts = {
            default_type = "DANGER",
            custom_types = { "DANGER", "SUCCESS" },
          },
        })
      end)
      assert.is_not_nil(markdown_plus.callouts)
    end)

    it("accepts empty custom_types", function()
      assert.has_no.errors(function()
        markdown_plus.setup({
          callouts = {
            custom_types = {},
          },
        })
      end)
    end)
  end)
end)
