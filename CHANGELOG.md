# Changelog

All notable changes to markdown-plus.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.4.1...v2.0.0) (2025-10-30)


### ⚠ BREAKING CHANGES

* None - all changes are internal refactoring

### Features

* add checkbox toggle functionality to list management ([67cab02](https://github.com/YousefHadder/markdown-plus.nvim/commit/67cab02ed753af240835d95c1d2971d6a6e8517d)), closes [#34](https://github.com/YousefHadder/markdown-plus.nvim/issues/34)
* Add checkbox toggle functionality to list management ([515ac81](https://github.com/YousefHadder/markdown-plus.nvim/commit/515ac81b4c2a8ec97e1b71da654dc14bf4ea843e))
* **headers:** add navigable TOC window with fold/unfold support ([22f9173](https://github.com/YousefHadder/markdown-plus.nvim/commit/22f9173f054f4d4c3d20e8c1fcddd2ae1a849121)), closes [#39](https://github.com/YousefHadder/markdown-plus.nvim/issues/39)
* **headers:** Add navigable TOC window with fold/unfold support ([b05d4ad](https://github.com/YousefHadder/markdown-plus.nvim/commit/b05d4ad0058b6f3b665e8ae2341e8b27d0e48f20))


### Bug Fixes

* address final 2 unresolved PR comments ([43ff833](https://github.com/YousefHadder/markdown-plus.nvim/commit/43ff833d39a45d7224e1d8e98cf47d54649b67c2))
* address new PR review comments ([89018be](https://github.com/YousefHadder/markdown-plus.nvim/commit/89018be65423550dd16ee8de0598470135960605))
* address PR comments - change insert keymap and improve cursor position ([bc0df18](https://github.com/YousefHadder/markdown-plus.nvim/commit/bc0df18b98457f0b7fd5c904653334db555e4be1))
* address PR review comments and add documentation ([21178d4](https://github.com/YousefHadder/markdown-plus.nvim/commit/21178d492793f67e8072b8d961e33502ad42650e))
* address remaining PR review comments ([57c7e50](https://github.com/YousefHadder/markdown-plus.nvim/commit/57c7e50e640dcdadc054e58b3c3ae69684c3ced5))
* **code_block:** add code_block to 'features' in init.lua ([57087e9](https://github.com/YousefHadder/markdown-plus.nvim/commit/57087e9b90bfa45f13b2f475b073c04fa5f24676))
* **code_block:** add code_block to 'known_feature_fields' ([17ea5df](https://github.com/YousefHadder/markdown-plus.nvim/commit/17ea5df299f23053ec765d707fc86cd4af5a374e))
* **code_block:** Add feature toggle check in `convert_to_code_block` ([fc76ece](https://github.com/YousefHadder/markdown-plus.nvim/commit/fc76ece427049bc81b356546396adce8d8c203b3))
* fix release-please file ([d8267b4](https://github.com/YousefHadder/markdown-plus.nvim/commit/d8267b43797501fd918f63af3432836a917b5808))
* **format:** change 'exit visual mode' ([0ac46cd](https://github.com/YousefHadder/markdown-plus.nvim/commit/0ac46cdf73211d169bf6625ea24b0be4e4174d9d))
* **format:** fix code block feature config validation and tests ([2f547d5](https://github.com/YousefHadder/markdown-plus.nvim/commit/2f547d5306d29d9d80b4f3546c5d46c4387946a8))
* **format:** stylua error ([9985ed1](https://github.com/YousefHadder/markdown-plus.nvim/commit/9985ed1223097ddc817b7a3ea1e1c30f2b1cd475))
* **headers:** improve syntax highlighting in TOC window ([da72a09](https://github.com/YousefHadder/markdown-plus.nvim/commit/da72a0989506626533914cf43556b8791849026c))
* improve input cancellation handling ([c423c18](https://github.com/YousefHadder/markdown-plus.nvim/commit/c423c18648a6962caf1fbfdc379ca61621a5c76c))
* improve type annotations and cursor positioning ([17ac22e](https://github.com/YousefHadder/markdown-plus.nvim/commit/17ac22e590410889308db6d1a52e3b443bd0b31c))
* invalid completion value error in utils.input() ([ba47824](https://github.com/YousefHadder/markdown-plus.nvim/commit/ba478243973ab38c8e3ac54dc83ffe27619ec42c))
* restore legacy TOC detection without HTML markers ([ea99dcf](https://github.com/YousefHadder/markdown-plus.nvim/commit/ea99dcfb285bc3f50e4fa19e681670845f3a1448))
* visual line mode formatting applies to entire selected lines ([31dab1a](https://github.com/YousefHadder/markdown-plus.nvim/commit/31dab1a41fad378276778feeb40f4c6b5acd907e))
* visual line mode formatting now applies to entire selected lines ([b5beb74](https://github.com/YousefHadder/markdown-plus.nvim/commit/b5beb74ba4b5e010791f13357c8369276b043b44))


### Code Refactoring

* extract keymap setup and common utilities to reduce duplication ([7ef663d](https://github.com/YousefHadder/markdown-plus.nvim/commit/7ef663d45bad4e6ff61a68ecf82038f4573fef01))

## [1.5.0] - 2025-10-29

### Added

- **TOC Window**: Interactive Table of Contents window with fold/unfold navigation
  - Commands: `:Toc` (vertical), `:Toch` (horizontal), `:Toct` (tab)
  - Keymap: `<leader>hT` to toggle TOC window
  - Features:
    - Toggle on/off (no duplicate windows)
    - Progressive disclosure: shows H1-H2 initially, expand with `l` key
    - Fold/unfold: `l` to expand, `h` to collapse or jump to parent
    - Jump to headers: press `<Enter>` on any header
    - Help popup: press `?` for keyboard shortcuts
    - Syntax highlighting: color-coded headers by level (H1-H6)
    - Visual markers: `▶` (collapsed), `▼` (expanded)
    - Auto-sizing: window adapts to content width
    - Status line: shows available commands
  - Configuration: `toc.initial_depth` to set initial display depth (default: 2)
  - `<Plug>` mapping: `<Plug>(MarkdownPlusOpenTocWindow)` for custom keymap
- **Code Block Conversion**: Added support for converting selected rows to code blocks in markdown.
  - Convert visual selection to code block with `<leader>mw` in visual mode.
  - `<Plug>` mapping: `<Plug>(MarkdownPlusCodeBlock)` for custom keymap configuration.
  - Prompts for code block language, with a configurable default language.
- **List Management**: Checkbox toggle functionality in normal, visual, and insert modes
  - `<leader>mx` in normal mode to toggle checkbox on current line
  - `<leader>mx` in visual mode to toggle checkboxes in selection
  - `<C-t>` in insert mode to toggle checkbox without leaving insert mode
  - Automatically adds `[ ]` checkbox to regular list items
  - Toggles between unchecked `[ ]` and checked `[x]` states
  - Works with all list types: unordered, ordered, letter-based, and parenthesized variants
- Comprehensive test suite with 32 new tests for checkbox functionality

### Fixed
- **Format toggling**: Fixed visual line mode (`V`) formatting to apply to entire selected lines instead of just the word at cursor position
  - When using `V` to select entire lines, formatting now correctly wraps the full line content
  - Properly detects line-wise visual mode and adjusts column positions to span from start to end of lines
  - Works with all formatting types: bold, italic, strikethrough, code, and clear formatting

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
