# Changelog

All notable changes to markdown-plus.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [1.3.1] - 2025-10-25

### Fixed
- **Visual mode selection issue**: Fixed error when formatting text on first visual selection
  - Implemented workaround for Neovim's visual mode marks (`'<` and `'>`) not updating until after exiting visual mode
  - Now uses `vim.fn.getpos('v')` and `vim.fn.getpos('.')` when in active visual mode
  - Falls back to marks when called after visual mode for compatibility
  - Added position normalization to handle backward selections (right-to-left, bottom-to-top)
  - Added visual selection restoration with `gv` to keep selection active after formatting
  - Added range validation to prevent API crashes with helpful error messages
  - Formatting now works correctly on the first selection without needing to reselect text
  - Expanded test coverage with 4 new visual mode selection tests (27 format tests total)

---

## [1.3.0] - 2025-10-23

### Added
- **vim.g configuration support**: Plugin can now be configured via `vim.g.markdown_plus` (table or function)
  - Supports both Lua and Vimscript configuration
  - Allows dynamic configuration via function
  - Merges with `setup()` configuration (setup takes precedence)
  - Full validation applies to vim.g config same as setup()
- **LuaRocks distribution**: Plugin now available via LuaRocks package manager
  - Created rockspec files (scm-1 and versioned)
  - Added LuaRocks installation instructions to README
  - Simplified installation without plugin manager
- Added `filetypes` field to configuration validation
- Comprehensive vim.g documentation in README and vimdoc

### Changed
- Configuration priority: Default < vim.g < setup() parameter
- Enhanced type annotations for configuration system
- Updated installation documentation with LuaRocks method

## [1.2.0] - 2025-01-20

### Added
- Complete test coverage for format and links modules (35 new tests)
- `<Plug>` mappings for all features (35+ mappings)
  - Full keymap customization support
  - Smart `hasmapto()` detection to avoid conflicts
  - Backward compatible with existing keymaps
- Comprehensive keymap customization documentation
- Complete `<Plug>` mapping reference in README

### Changed
- Default keymaps now check for existing mappings before setting
- Updated contribution guidelines to allow direct collaboration

### Fixed
- Critical keymap bug in visual mode mappings
- Visual mode `<Plug>` mappings now use Lua functions instead of string commands
- Added proper keymap descriptions for better discoverability

## [1.1.0] - 2025-01-19

### Added
- Links and References management module
  - Insert and edit markdown links
  - Convert text selection to links
  - Auto-convert bare URLs to markdown links
  - Convert between inline and reference-style links
  - Smart reference ID generation and reuse
- Support for multiple filetypes configuration
  - Plugin can now work with any filetype, not just markdown
  - Configurable via `filetypes` option in setup

### Changed
- Plugin now enables for configured filetypes instead of just markdown
- Updated documentation for multi-filetype support

### Fixed
- Corrected documentation keymaps to match implementation
- Fixed link detection edge cases
- Removed unimplemented features from config and docs

## [1.0.0] - 2025-01-19

### Added

#### Headers Module
- Header promotion/demotion with `<leader>h+` and `<leader>h-`
- Jump between headers with `]]` and `[[`
- Set specific header levels with `<leader>h1` through `<leader>h6`
- Generate Table of Contents with `<leader>ht`
- Update existing TOC with `<leader>hu`
- Follow TOC links with `gd`
- TOC duplicate prevention using HTML comment markers (`<!-- TOC -->` / `<!-- /TOC -->`)
- GitHub-style slug generation for anchors

#### List Module
- Auto-continuation of list items on `<CR>` in insert mode
- Context-aware `o` and `O` in normal mode for list items
- Intelligent list indentation with `<Tab>` and `<S-Tab>` (insert mode)
- Smart backspace with `<BS>` to remove empty list markers
- Automatic renumbering of ordered lists on text changes
- Manual renumbering with `<leader>mr`
- Debug command `<leader>md` for troubleshooting list detection
- Support for nested lists with proper indentation handling
- Empty list item removal (press `<CR>` twice to exit list)

#### Format Module
- Toggle bold formatting with `<leader>mb` (normal + visual mode)
- Toggle italic formatting with `<leader>mi` (normal + visual mode)
- Toggle strikethrough with `<leader>ms` (normal + visual mode)
- Toggle inline code with `<leader>mc` (normal + visual mode)
- Clear all formatting with `<leader>mC` (normal + visual mode)
- Smart word boundary detection for formatting operations

#### Documentation
- Comprehensive help file accessible via `:help markdown-plus`
- Complete API documentation for all modules
- Usage examples and troubleshooting guide
- Installation instructions for lazy.nvim

### Technical Details
- Context-aware keymaps that only activate when appropriate
- Proper fallback to default Vim behavior outside of lists
- No interference with normal mode operations
- Buffer-local keymaps for Markdown files only
- Automatic feature enablement via FileType autocmd

### Changed
- Initial stable release

### Fixed
- List operations now properly enter insert mode on non-list lines
- Fixed `<CR>` behavior to work correctly on regular text
- Removed global `<CR>` mapping that interfered with normal mode
- All keymaps now respect context (list vs non-list, insert vs normal)

---

## Historical Note

The improvements from Phase 1 and Phase 2 (testing infrastructure, type safety, code quality tools, CI/CD) were integrated into versions 1.1.0 and 1.2.0 as part of the overall development process. These foundational improvements support all current and future features.

[1.3.1]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.2.0
[1.1.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.1.0
[1.0.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.0.0
