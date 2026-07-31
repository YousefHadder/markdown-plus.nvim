-- Isolated Neovim config for end-to-end keymap tests.
--
-- This file is the ONLY config the e2e harness loads. It deliberately does not read
-- ~/.config/nvim, does not use a plugin manager, and loads nothing but the plugin under
-- test, so a result here is a property of the plugin rather than of whoever is running it.
-- `scripts/run-e2e.sh` additionally points every XDG_* dir at a fresh temp directory, so
-- shada, swap and state from the developer's real Neovim cannot leak in either.

-- The plugin under test, resolved from the repo root the runner passes in.
local root = os.getenv("MARKDOWN_PLUS_ROOT") or vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

-- No writing to disk: these tests only ever inspect buffer contents.
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.shadafile = "NONE"

-- Deterministic indentation. Several cases assert exact leading whitespace, so these must
-- not be inherited from the environment.
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.autoindent = true

-- The checkbox toggle default is <localleader>mx, so localleader must be defined before
-- the plugin registers its buffer-local defaults.
vim.g.mapleader = "\\"
vim.g.maplocalleader = ","

-- Load the plugin's own entry point exactly as a user would.
vim.cmd("runtime! plugin/**/*.lua")
require("markdown-plus").setup({})

-- Guard against the thing this file exists to prevent: if a personal config ever ends up on
-- the runtimepath, every downstream assertion becomes untrustworthy, so fail loudly instead.
local rtp = vim.o.runtimepath
local home = vim.fn.expand("~")
for entry in vim.gsplit(rtp, ",", { plain = true }) do
  local is_user_config = entry:find(home .. "/.config/nvim", 1, true)
    or entry:find(home .. "/.local/share/nvim/lazy", 1, true)
    or entry:find(home .. "/.local/share/nvim/site", 1, true)
  if is_user_config then
    io.stderr:write("ISOLATION FAILURE: personal config on runtimepath: " .. entry .. "\n")
    vim.cmd("cquit 2")
  end
end
