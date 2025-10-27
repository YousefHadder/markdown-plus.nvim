# Changelog

All notable changes to markdown-plus.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [1.4.1] - 2025-10-27

### Added
- Improved release workflow with automated PR creation and auto-merge
- Pre-release verification step to ensure tests, linting, and formatting pass before creating releases
- Rollback mechanism for failed releases
- Enhanced release notes with installation instructions for multiple package managers

### Changed
- Refactored release workflow into reusable scripts in `scripts/` directory
- Upgraded to StyLua GitHub Action for better caching and reliability
- Improved LuaRocks workflow with better error handling and validation

### Fixed
- Fixed secret accessibility issues in GitHub Actions conditionals
- Improved temporary file cleanup in workflows
- Enhanced security with checksum verification for downloaded binaries
- **List renumbering**: Fixed nested and blank-line-separated ordered list renumbering
  - Nested lists now correctly restart numbering when returning to parent level (e.g., `1. A → 1. B, 2. C → 2. D → 1. E, 2. F` instead of `3. E, 4. F`)
  - Blank lines now properly separate lists into distinct groups that restart numbering
  - Applies to all ordered list types: numbered (`1.`, `2.`), letter-based (`a.`, `A.`), and parenthesized variants (`1)`, `a)`)
  - Works at any nesting depth


---

## [1.4.0] - 2025-10-25

### Added
- **Quotes Management**: Added support for toggling blockquotes in markdown
  - Toggle blockquote on current line with `<leader>mq` in normal mode
  - Toggle blockquote on selected lines in visual mode with `<leader>mq`
  - `<Plug>` mapping: `<Plug>(MarkdownPlusToggleQuote)` for custom keymap configuration
  - Smart handling of existing blockquotes

- **Additional list types support**:
  - Letter-based lists: `a.`, `b.`, `c.`, ... `z.` (lowercase)
  - Letter-based lists: `A.`, `B.`, `C.`, ... `Z.` (uppercase)
  - Parenthesized ordered lists: `1)`, `2)`, `3)`
  - Parenthesized letter lists: `a)`, `b)`, `c)` and `A)`, `B)`, `C)`
  - All new list types support auto-continuation, indentation, renumbering, and checkboxes
  - Single-letter support with wraparound (z→a, Z→A)

### Changed
- **List module refactoring**:
  - Pattern-driven architecture with `PATTERN_CONFIG` table
  - Extracted helper functions: `get_next_marker()`, `get_previous_marker()`, `extract_list_content()`
  - Reduced code size from 878 to 763 lines (13% reduction)
  - Simplified `parse_list_line()` from ~170 lines to ~30 lines
  - Added module-level constants for delimiters

### Fixed
- Invalid pattern capture error when indenting parenthesized lists
- Tab/Shift-Tab now work correctly with all list types including parenthesized variants
- 'O' command (insert above) now correctly calculates markers for letter-based lists

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

[1.4.1]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.2.0
[1.1.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.1.0
[1.0.0]: https://github.com/YousefHadder/markdown-plus.nvim/releases/tag/v1.0.0
