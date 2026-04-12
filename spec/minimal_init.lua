-- spec/minimal_init.lua
-- Minimal init for running tests

if os.getenv("MARKDOWN_PLUS_ENABLE_COVERAGE") == "1" then
  local ok, err = pcall(require, "luacov")
  if not ok then
    error("Failed to load luacov: " .. err)
  end

  local runner = require("luacov.runner")
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      runner.save_stats()
      runner.shutdown()
    end,
  })
end

-- Set runtimepath to include plenary and this plugin
local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

-- Find plenary.nvim
local plenary_dir = os.getenv("PLENARY_DIR")

if not plenary_dir or vim.fn.isdirectory(plenary_dir) == 0 then
  local possible_paths = {
    vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
    vim.fn.expand("~/.local/share/nvim/site/pack/vendor/start/plenary.nvim"),
    vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  }

  for _, path in ipairs(possible_paths) do
    if vim.fn.isdirectory(path) == 1 then
      plenary_dir = path
      break
    end
  end
end

if not plenary_dir or vim.fn.isdirectory(plenary_dir) == 0 then
  error("plenary.nvim not found! Searched paths and PLENARY_DIR env var")
end

-- Set up runtimepath
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(plenary_dir)

-- Disable swap files for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Make spec/ loadable so helpers can be required as spec.helpers
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

-- Ensure plugin files are loaded
vim.cmd("runtime! plugin/**/*.vim")
vim.cmd("runtime! plugin/**/*.lua")
