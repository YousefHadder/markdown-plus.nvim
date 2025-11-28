# Changelog

All notable changes to markdown-plus.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.1](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.9.0...v1.9.1) (2025-11-28)


### Bug Fixes

* **footnotes:** add reference only when inserting existing footnote ID ([#137](https://github.com/YousefHadder/markdown-plus.nvim/issues/137)) ([8ba242b](https://github.com/YousefHadder/markdown-plus.nvim/commit/8ba242b941ec6233d351ac3ec1f529f7df9f67b8))
* **list:** parse empty list items without trailing space ([#140](https://github.com/YousefHadder/markdown-plus.nvim/issues/140)) ([e151f19](https://github.com/YousefHadder/markdown-plus.nvim/commit/e151f19a203b427e7a443a7a38247e676221a2e8))
* **list:** separate lists by marker type per CommonMark spec ([#139](https://github.com/YousefHadder/markdown-plus.nvim/issues/139)) ([d3e139b](https://github.com/YousefHadder/markdown-plus.nvim/commit/d3e139b8ebe76aa8f02d5afc850ce9a0df274cd0))

## [1.9.0](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.8.0...v1.9.0) (2025-11-27)


### Features

* add comprehensive image link support ([#117](https://github.com/YousefHadder/markdown-plus.nvim/issues/117)) ([#123](https://github.com/YousefHadder/markdown-plus.nvim/issues/123)) ([6507297](https://github.com/YousefHadder/markdown-plus.nvim/commit/6507297dcbbd9e5ea5be49449629a7cdbb0d5a4e))
* **callouts:** add github flavored markdown callouts support ([#121](https://github.com/YousefHadder/markdown-plus.nvim/issues/121)) ([a6ff424](https://github.com/YousefHadder/markdown-plus.nvim/commit/a6ff4249e83f08317a3fdd6335d463a4a9d7b541))
* **footnotes:** add comprehensive footnotes support ([#135](https://github.com/YousefHadder/markdown-plus.nvim/issues/135)) ([a18473f](https://github.com/YousefHadder/markdown-plus.nvim/commit/a18473f19f5c635b1c6be39b0bf16349f0e40694))
* **format:** add dot-repeat support for normal mode formatting actions ([#132](https://github.com/YousefHadder/markdown-plus.nvim/issues/132)) ([300abe9](https://github.com/YousefHadder/markdown-plus.nvim/commit/300abe94983fbd46018d4f3283953f7185e1e740))


### Bug Fixes

* **bug:** basic lazy-loading setup ([#128](https://github.com/YousefHadder/markdown-plus.nvim/issues/128)) ([35c977e](https://github.com/YousefHadder/markdown-plus.nvim/commit/35c977ef2f6c1ca1c988782869d97d1b788792de))
* **bug:** correct multi-byte character handling in get_visual_selection ([#126](https://github.com/YousefHadder/markdown-plus.nvim/issues/126)) ([0b74213](https://github.com/YousefHadder/markdown-plus.nvim/commit/0b74213f846f9c3bd72aa40eacd5626b6b55be7e))
* **format:** use global operatorfunc instead of buffer-local ([#133](https://github.com/YousefHadder/markdown-plus.nvim/issues/133)) ([8d97fc8](https://github.com/YousefHadder/markdown-plus.nvim/commit/8d97fc89af60f6a4e6f4b40a3c5d61f3c50831e1))

## [1.8.0](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.7.1...v1.8.0) (2025-11-09)


### Features

* **tables:** add phase 2 table features ([#114](https://github.com/YousefHadder/markdown-plus.nvim/issues/114)) ([2924405](https://github.com/YousefHadder/markdown-plus.nvim/commit/292440560154e896c36a12ddb88a85e4de6fbeac))

## [1.7.1](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.7.0...v1.7.1) (2025-11-07)


### Bug Fixes

* allow custom keymaps when disabled and fix list enter splitting at last char ([5748974](https://github.com/YousefHadder/markdown-plus.nvim/commit/57489741a1c5a0f65ed1ba96a8a16b901fac613b))
* **bug:** critical table bugs, add health check, and improve reference id handling ([e31d3a0](https://github.com/YousefHadder/markdown-plus.nvim/commit/e31d3a015a2e53655c135f305b6170c5ec8c7b6e))
* **bug:** custom keymaps and list enter splitting bugs ([f3ca2fd](https://github.com/YousefHadder/markdown-plus.nvim/commit/f3ca2fd6791b9ffdf8d891bc9893766e9ad15540))
* **bug:** list continuation line handling and refactor shared utilities ([51116c8](https://github.com/YousefHadder/markdown-plus.nvim/commit/51116c874f4795a6be5d8027320319cff7975ac9))
* **bug:** process unicode character properly ([968d132](https://github.com/YousefHadder/markdown-plus.nvim/commit/968d132f67f51450414862148af751c87c5a350e))
* critical table bugs, add health check, and improve reference ID handling ([6b8795c](https://github.com/YousefHadder/markdown-plus.nvim/commit/6b8795c907f9d819849cbeb62135738a99e31857))
* handle list continuation lines in renumbering and refactor shared utilities ([a198f62](https://github.com/YousefHadder/markdown-plus.nvim/commit/a198f62708998efc97879fc534651a2985e4ed44))
* **list:** continue lists when enter is pressed on indented continuation lines ([7d0d052](https://github.com/YousefHadder/markdown-plus.nvim/commit/7d0d05212aeb6a012fc0ae346f39c076ed11a957))
* **list:** continue lists when Enter is pressed on indented continuation lines ([90a3adc](https://github.com/YousefHadder/markdown-plus.nvim/commit/90a3adc29ba77cc20ca0daeb39941b88135ed077))
* process unicode character properly ([6ac2e81](https://github.com/YousefHadder/markdown-plus.nvim/commit/6ac2e811983c95b0a12b1d4abbdafc99e87a50dd))

## [1.7.0](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.6.0...v1.7.0) (2025-11-04)


### Features

* **table:** add insert mode cell navigation with Alt+hjkl and circular wrapping ([f9d8199](https://github.com/YousefHadder/markdown-plus.nvim/commit/f9d8199e818a27a900b14ccc46f27066a168c596))


### Bug Fixes

* **bug:** buffer-local keymap recreation and enhanced list content handling ([9799f35](https://github.com/YousefHadder/markdown-plus.nvim/commit/9799f35b74d5e1302f461caa880a25f340ad51de))
* TOC generation and window now respect initial_depth configuration ([5f35596](https://github.com/YousefHadder/markdown-plus.nvim/commit/5f355963ae7f4f2b112569b94104771b1c9163d1))
* TOC generation and window now respect initial_depth configuration ([36bcee7](https://github.com/YousefHadder/markdown-plus.nvim/commit/36bcee79e5841124ddc73c51e4d3162776beeecf))

## [1.6.0](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.5.1...v1.6.0) (2025-11-01)


### Features

* implement Phase 1 table support ([fed858e](https://github.com/YousefHadder/markdown-plus.nvim/commit/fed858ed34fb8cf2db741f3b00146c1ac9feebbc))
* Phase 1 Table Support - Complete Implementation ([78ab892](https://github.com/YousefHadder/markdown-plus.nvim/commit/78ab892f58135117fe8bae81fb76fb693135afd3))


### Bug Fixes

* address Copilot PR review comments ([71a4c26](https://github.com/YousefHadder/markdown-plus.nvim/commit/71a4c26f1cd5e718308d3727ff58b96de5b0e7f2))
* address PR review comments and critical bugs ([0b2a42a](https://github.com/YousefHadder/markdown-plus.nvim/commit/0b2a42a3028433e50c3f8c39210eab69c2c3f762))
* correct LuaRocks publication workflow ([ee7f149](https://github.com/YousefHadder/markdown-plus.nvim/commit/ee7f14932f1afe5c7c058d2f39e1ac66ea19cde9))
* correct LuaRocks publication workflow ([83aba4e](https://github.com/YousefHadder/markdown-plus.nvim/commit/83aba4e0bee5d9b5cf6c1aaa0b280c7a4edbde3c))
* correct row bounds validation and line calculation ([e9ece1c](https://github.com/YousefHadder/markdown-plus.nvim/commit/e9ece1c3b00b970b94e73af3829e9eba9d4827d0))
* correct separator width generation and row deletion validation ([2f9a49f](https://github.com/YousefHadder/markdown-plus.nvim/commit/2f9a49f83221eace02ddb297bc0c18086c393f63))
* replace hardcoded username with github.repository_owner ([690815c](https://github.com/YousefHadder/markdown-plus.nvim/commit/690815cadf4301d976da4530922147b2c3ed5d6f))

## [1.5.1](https://github.com/YousefHadder/markdown-plus.nvim/compare/v1.5.0...v1.5.1) (2025-10-30)


### Bug Fixes

* address final 2 unresolved PR comments ([3304632](https://github.com/YousefHadder/markdown-plus.nvim/commit/3304632d1fe57750bccbcf2185969159943012ee))
* address remaining PR review comments ([2a16266](https://github.com/YousefHadder/markdown-plus.nvim/commit/2a162660c22b20f53edbbffe7b3da3c6d27595aa))
* fix release-please file ([fe79a36](https://github.com/YousefHadder/markdown-plus.nvim/commit/fe79a3642b2c54d283e6787df01144122303ded2))
* improve input cancellation handling ([7f5724b](https://github.com/YousefHadder/markdown-plus.nvim/commit/7f5724b6fbc81e29f177232a9593743ef2585966))
* improve type annotations and cursor positioning ([570440b](https://github.com/YousefHadder/markdown-plus.nvim/commit/570440ba2fff3d17b2f6db292524aa50f49a3d36))
* invalid completion value error in utils.input() ([91bdb2c](https://github.com/YousefHadder/markdown-plus.nvim/commit/91bdb2c5fbc88e92dfea717c02a1b10998a2cd02))
* restore legacy TOC detection without HTML markers ([e7aefb0](https://github.com/YousefHadder/markdown-plus.nvim/commit/e7aefb0f565e73d46768e022fcba0281f3edf7ef))

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
