rockspec_format = "3.0"
package = "markdown-plus.nvim"
version = "1.5.0-1"

source = {
  url = "git://github.com/YousefHadder/markdown-plus.nvim.git",
  tag = "v1.5.0",
}

description = {
  summary = "Modern Markdown editing for Neovim",
  detailed = [[
    A comprehensive Neovim plugin that provides modern markdown editing
    capabilities, implementing features found in popular editors like Typora,
    Mark Text, and Obsidian.

    Features:
    - Smart list management with auto-continuation and renumbering
    - Text formatting (bold, italic, strikethrough, inline code)
    - Header navigation and promotion/demotion
    - Table of contents generation with GitHub-compatible slugs
    - Link management and reference-style conversion
    - Full <Plug> mapping support for customization
    - vim.g configuration support for Vimscript compatibility
    - Works with any filetype, not just markdown
  ]],
  homepage = "https://github.com/yousefhadder/markdown-plus.nvim",
  license = "MIT",
  labels = {
    "neovim",
    "markdown",
    "editor",
    "productivity",
  },
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  copy_directories = {
    "doc",
    "plugin",
  },
}

test_dependencies = {
  "nlua",
}

test = {
  type = "busted",
}
