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
end)
