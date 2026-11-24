-- Configuration for luacheck (Lua linter)
-- https://luacheck.readthedocs.io/en/stable/

std = "luajit"

globals = {
  "vim",
}

-- Ignore warnings about line length
max_line_length = false

-- Allow self variables (methods)
self = false

-- Exclude files/directories
exclude_files = {
  ".luarc.json",
}

-- Ignore specific warnings
ignore = {
  "212", -- Unused argument (common in callbacks)
  "213", -- Unused loop variable
}
