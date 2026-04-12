-- Tests for markdown-plus treesitter support module
describe("markdown-plus treesitter", function()
  local treesitter
  local saved_treesitter
  local saved_create_augroup
  local saved_create_autocmd
  local registered_cache_callback
  local parser_calls
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "markdown"

    parser_calls = 0
    registered_cache_callback = nil

    saved_treesitter = vim.treesitter
    vim.treesitter = {
      get_node = function()
        return nil
      end,
      get_parser = function(bufnr)
        -- M.is_available() probes bufnr=0; don't count probe calls.
        if bufnr == 0 then
          return {
            parse = function() end,
            trees = function()
              return {}
            end,
          }
        end

        parser_calls = parser_calls + 1
        return {
          parse = function() end,
          trees = function()
            return {}
          end,
        }
      end,
    }

    saved_create_augroup = vim.api.nvim_create_augroup
    saved_create_autocmd = vim.api.nvim_create_autocmd
    vim.api.nvim_create_augroup = function()
      return 999
    end
    vim.api.nvim_create_autocmd = function(_, opts)
      registered_cache_callback = opts.callback
    end

    package.loaded["markdown-plus.treesitter"] = nil
    treesitter = require("markdown-plus.treesitter")
  end)

  after_each(function()
    package.loaded["markdown-plus.treesitter"] = nil
    vim.treesitter = saved_treesitter
    vim.api.nvim_create_augroup = saved_create_augroup
    vim.api.nvim_create_autocmd = saved_create_autocmd

    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("clears parser cache for buffers that are deleted", function()
    assert.is_function(registered_cache_callback)

    assert.is_not_nil(treesitter.get_parser())
    assert.equals(1, parser_calls)

    -- Second call should use per-buffer changedtick cache
    assert.is_not_nil(treesitter.get_parser())
    assert.equals(1, parser_calls)

    -- Simulate BufDelete/BufWipeout callback clearing this buffer's cache entry
    registered_cache_callback({ buf = buf })

    assert.is_not_nil(treesitter.get_parser())
    assert.equals(2, parser_calls)
  end)

  describe("find_ancestor", function()
    it("returns nil when node is nil", function()
      assert.is_nil(treesitter.find_ancestor(nil, "heading"))
    end)

    it("returns nil when node is nil with table of types", function()
      assert.is_nil(treesitter.find_ancestor(nil, { "heading", "paragraph" }))
    end)

    it("returns matching node with string type", function()
      local mock_node = {
        type = function()
          return "heading"
        end,
        parent = function()
          return nil
        end,
      }
      local result = treesitter.find_ancestor(mock_node, "heading")
      assert.is_not_nil(result)
      assert.equals("heading", result:type())
    end)

    it("returns matching node with table of types", function()
      local mock_node = {
        type = function()
          return "paragraph"
        end,
        parent = function()
          return nil
        end,
      }
      local result = treesitter.find_ancestor(mock_node, { "heading", "paragraph" })
      assert.is_not_nil(result)
      assert.equals("paragraph", result:type())
    end)

    it("walks up the tree to find ancestor", function()
      local parent_node = {
        type = function()
          return "list"
        end,
        parent = function()
          return nil
        end,
      }
      local child_node = {
        type = function()
          return "list_item"
        end,
        parent = function()
          return parent_node
        end,
      }
      local result = treesitter.find_ancestor(child_node, "list")
      assert.is_not_nil(result)
      assert.equals("list", result:type())
    end)

    it("returns nil when no ancestor matches", function()
      local mock_node = {
        type = function()
          return "paragraph"
        end,
        parent = function()
          return nil
        end,
      }
      local result = treesitter.find_ancestor(mock_node, "heading")
      assert.is_nil(result)
    end)
  end)

  describe("is_available", function()
    it("returns a boolean value", function()
      local result = treesitter.is_available()
      assert.is_true(type(result) == "boolean")
    end)
  end)

  describe("node type constants", function()
    it("has FENCED_CODE_BLOCK as a string", function()
      assert.equals("string", type(treesitter.nodes.FENCED_CODE_BLOCK))
      assert.equals("fenced_code_block", treesitter.nodes.FENCED_CODE_BLOCK)
    end)

    it("has HEADING as a string", function()
      assert.equals("string", type(treesitter.nodes.HEADING))
      assert.equals("heading", treesitter.nodes.HEADING)
    end)

    it("has PARAGRAPH as a string", function()
      assert.equals("string", type(treesitter.nodes.PARAGRAPH))
      assert.equals("paragraph", treesitter.nodes.PARAGRAPH)
    end)

    it("has LIST as a string", function()
      assert.equals("string", type(treesitter.nodes.LIST))
      assert.equals("list", treesitter.nodes.LIST)
    end)

    it("has PIPE_TABLE as a string", function()
      assert.equals("string", type(treesitter.nodes.PIPE_TABLE))
      assert.equals("pipe_table", treesitter.nodes.PIPE_TABLE)
    end)

    it("has BLOCK_QUOTE as a string", function()
      assert.equals("string", type(treesitter.nodes.BLOCK_QUOTE))
      assert.equals("block_quote", treesitter.nodes.BLOCK_QUOTE)
    end)
  end)
end)
