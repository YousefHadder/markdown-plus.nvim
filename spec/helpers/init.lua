-- spec/helpers/init.lua
-- Shared test helpers for markdown-plus.nvim test suite
-- Provides buffer management, cursor helpers, and config snapshot utilities

local M = {}

--- Create a scratch buffer with the given lines and filetype
---@param lines string[] Lines to set in the buffer
---@param filetype? string Filetype to set (default: "markdown")
---@return number bufnr The buffer number
function M.create_buf(lines, filetype)
  vim.cmd("enew")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { "" })
  vim.bo[bufnr].filetype = filetype or "markdown"
  vim.bo[bufnr].swapfile = false
  return bufnr
end

--- Delete the current buffer (safe cleanup for after_each)
function M.destroy_buf()
  pcall(vim.cmd, "bdelete!")
end

--- Get the current buffer's lines
---@return string[]
function M.buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

--- Assert that the current buffer matches the expected lines
--- Note: Uses busted's assert global (available in spec context)
---@param expected string[]
function M.assert_buf(expected)
  assert.are.same(expected, M.buf_lines()) -- luacheck: ignore 143
end

--- Set cursor position (1-indexed row, 0-indexed col)
---@param row number 1-indexed row
---@param col number 0-indexed column
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

--- Get cursor position
---@return number[] {row, col} — row is 1-indexed, col is 0-indexed
function M.get_cursor()
  return vim.api.nvim_win_get_cursor(0)
end

--- Run a function with temporary config overrides, then restore
---@param overrides table Config overrides to apply
---@param fn fun() Function to run with the overrides
function M.with_config(overrides, fn)
  local mp = require("markdown-plus")
  local saved = vim.deepcopy(mp.config)
  mp.setup(overrides)
  local ok, err = pcall(fn)
  if mp.teardown then
    mp.teardown()
  end
  mp.config = saved
  if not ok then
    error(err)
  end
end

-- Re-export mocks and async sub-modules for convenience
M.mocks = require("spec.helpers.mocks")
M.async = require("spec.helpers.async")

return M
