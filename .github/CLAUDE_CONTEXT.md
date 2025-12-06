# Claude AI Context Document for markdown-plus.nvim

> **Note**: This document is specifically designed for AI assistants (like Claude) to quickly understand the markdown-plus.nvim codebase in new sessions. For human contribution guidelines, see [CONTRIBUTING.md](../CONTRIBUTING.md).

## How to Use This Document

At the start of each Claude session working on this project, say:
> "Read .github/CLAUDE_CONTEXT.md and analyze the codebase to understand its structure, patterns, and practices."

This will enable Claude to:
- Answer questions about the codebase with full context
- Implement new features following established patterns
- Fix bugs with understanding of the architecture
- Write tests that match existing style
- Review code against project standards

---

## 1. Project Overview

**Purpose**: Provide a full markdown editing experience in Neovim with modern features found in popular editors like Typora, Mark Text, and Obsidian.

**Language**: Lua (Neovim plugin)

**License**: MIT

**Test Coverage**: 85%+

**Key Selling Points**:
- Zero dependencies (works standalone)
- Works with any filetype (not just markdown)
- Full test coverage with Busted and plenary.nvim
- Extensively documented with LuaCATS type annotations
- Modular architecture allowing feature toggles

**Minimum Requirements**:
- Neovim 0.11+
- Lua 5.1+

---

## 2. Architecture & Structure

The plugin follows a modular architecture where each feature is self-contained:

```
lua/markdown-plus/
├── init.lua              # Main entry point, setup(), config management
├── types.lua             # LuaCATS type definitions for entire plugin
├── utils.lua             # Shared utility functions
├── health.lua            # Neovim health check (:checkhealth markdown-plus)
├── keymap_helper.lua     # Keymap utilities for consistent mapping patterns
├── config/
│   └── validate.lua      # Configuration validation logic
├── callouts/             # GitHub-flavored callout blocks (NOTE, WARNING, etc.)
│   └── init.lua
├── footnotes/            # Footnote management (creation, navigation, cleanup)
│   └── init.lua
├── format/               # Inline text formatting (bold, italic, code, strikethrough)
│   └── init.lua
├── headers/              # Headers manipulation and TOC generation
│   └── init.lua
├── images/               # Image link operations
│   └── init.lua
├── links/                # Link operations (create, follow, convert)
│   └── init.lua
├── list/                 # List management (bullet, numbered, checkboxes)
│   ├── init.lua          # Main module entry point
│   ├── parser.lua        # List pattern parsing
│   ├── handlers.lua      # Event handlers (Enter key, etc.)
│   ├── renumber.lua      # Ordered list renumbering
│   ├── checkbox.lua      # Checkbox toggling
│   └── shared.lua        # Shared list utilities
├── quote/                # Blockquote handling
│   └── init.lua
└── table/                # Table formatting, alignment, and navigation
    └── init.lua

plugin/
└── markdown-plus.lua     # Plugin initialization (lazy-load guard)

spec/
├── minimal_init.lua      # Test environment setup
└── markdown-plus/        # Test suites (mirrors lua/ structure)
    ├── config_spec.lua
    ├── utils_spec.lua
    ├── list_spec.lua
    ├── headers_spec.lua
    └── ... (more test files)

doc/
└── markdown-plus.txt     # Vim help documentation

rockspecs/                # LuaRocks package specifications
```

---

## 3. Code Patterns & Practices

### Module Pattern

Each feature module follows a consistent pattern:

```lua
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Setup module with configuration
---@param config markdown-plus.InternalConfig Plugin configuration
function M.setup(config)
  M.config = config or {}
end

---Enable features for current buffer
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end
  
  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for this module
function M.setup_keymaps()
  -- Use keymap_helper for consistent keymap setup
end

return M
```

### Configuration Management

1. **Definition**: Configuration types are defined in `lua/markdown-plus/types.lua` using LuaCATS annotations
2. **Validation**: All user configuration is validated in `config/validate.lua` using `vim.validate()`
3. **Merging**: Configuration is merged with defaults in `init.lua` using `vim.tbl_deep_extend()`
4. **Sources**: Configuration can come from:
   - `require('markdown-plus').setup(opts)` (highest priority)
   - `vim.g.markdown_plus` (table or function)
   - Default values in `init.lua`

### Type Annotations

All public functions use LuaCATS annotations:

```lua
---Function description
---@param name string Parameter description
---@param opts? table Optional parameter (note the ?)
---@return boolean success True if successful
---@return string|nil error Error message if failed
function M.do_something(name, opts)
  -- Implementation
end
```

### Naming Conventions

- **Functions and variables**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE` (though rarely used)
- **Module files**: `snake_case.lua`
- **Type definitions**: `markdown-plus.TypeName` (namespaced)

### Code Style

- **Formatter**: StyLua with 120 char width, 2-space indent (`.stylua.toml`)
- **Linter**: Luacheck with vim global allowed (`.luacheckrc`)
- **Globals**: Only `vim` global is allowed; all other variables must be `local`
- **Comments**: Document complex logic and all public APIs

### Testing

- **Framework**: Busted with plenary.nvim
- **Location**: `spec/markdown-plus/` (mirrors `lua/markdown-plus/`)
- **Structure**: `describe` → `before_each` → `it` blocks
- **Coverage**: Aim for all public functions, edge cases, error cases
- **Pattern**:
  1. Create buffer with `vim.api.nvim_create_buf()`
  2. Set filetype to markdown
  3. Run test
  4. Cleanup buffer in `after_each`

### Commit Messages

- **Format**: Conventional Commits (enforced via commitlint)
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`
- **Breaking changes**: Use `!` after type or `BREAKING CHANGE:` in footer
- **Examples**:
  - `feat(headers): add support for setext headers`
  - `fix(list): correct variable reference in parse_list_line`
  - `test(config): add validation test cases`

---

## 4. Development Workflow

### Quality Commands

Run these commands frequently during development:

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=spec/markdown-plus/config_spec.lua

# Watch mode (requires entr)
make test-watch

# Lint code
make lint

# Format code
make format

# Check formatting without modifying
make format-check

# Run all CI checks (lint + format-check + test)
make check
```

### Development Cycle

1. **Understand the task** - Read related code and documentation
2. **Write tests first** - Create failing tests for new functionality
3. **Implement changes** - Make minimal, focused changes
4. **Run tests** - `make test` to verify functionality
5. **Lint and format** - `make lint && make format`
6. **Commit** - Use conventional commit format
7. **Iterate** - Repeat as needed

---

## 5. Key Configuration Options

The main configuration structure (from `lua/markdown-plus/init.lua`):

```lua
{
  -- Master toggle
  enabled = true,
  
  -- Individual feature toggles
  features = {
    list_management = true,
    text_formatting = true,
    links = true,
    images = true,
    headers_toc = true,
    quotes = true,
    callouts = true,
    code_block = true,
    table = true,
    footnotes = true,
  },
  
  -- Keymap configuration
  keymaps = {
    enabled = true,  -- Enable default keymaps
  },
  
  -- Which filetypes to activate on
  filetypes = { "markdown" },
  
  -- Table-specific configuration
  table = {
    enabled = true,
    auto_format = true,
    default_alignment = "left",  -- "left" | "center" | "right"
    confirm_destructive = true,
    keymaps = {
      enabled = true,
      prefix = "<leader>t",
      insert_mode_navigation = true,  -- Alt+hjkl navigation
    },
  },
  
  -- Callout configuration
  callouts = {
    default_type = "NOTE",
    custom_types = {},  -- Add custom callout types beyond GFM standard
  },
  
  -- Code block configuration
  code_block = {
    enabled = true,
  },
  
  -- Footnote configuration
  footnotes = {
    section_header = "Footnotes",
    confirm_delete = true,
  },
  
  -- TOC configuration
  toc = {
    initial_depth = 2,  -- 1-6
  },
}
```

---

## 6. Feature Modules

Brief description of each module's purpose:

### list (lua/markdown-plus/list/)
- Manage bullet and numbered lists
- Auto-continuation on Enter
- Indent/outdent with Tab/Shift-Tab
- Checkbox toggling
- Ordered list renumbering

### format (lua/markdown-plus/format/)
- Toggle inline formatting (bold, italic, code, strikethrough)
- Clear all formatting
- Smart selection handling

### headers (lua/markdown-plus/headers/)
- Navigate between headers
- Promote/demote header levels
- Generate GitHub-compatible table of contents
- Update existing TOC

### links (lua/markdown-plus/links/)
- Create markdown links
- Follow links (file paths, URLs)
- Convert between inline and reference links
- Auto-link URLs

### images (lua/markdown-plus/images/)
- Image link operations
- Insert image links
- Preview images (if supported)

### quotes (lua/markdown-plus/quote/)
- Toggle blockquotes
- Manage multi-line quotes
- Nest quotes

### callouts (lua/markdown-plus/callouts/)
- GitHub-flavored markdown callouts
- Support for NOTE, WARNING, IMPORTANT, TIP, CAUTION
- Custom callout types

### table (lua/markdown-plus/table/)
- Create and format tables
- Align columns (left, center, right)
- Navigate cells with Tab/Enter
- Transpose and sort
- Auto-formatting on edit

### footnotes (lua/markdown-plus/footnotes/)
- Create footnotes
- Navigate to/from footnotes
- Clean up unused footnotes
- Auto-generate footnote section

---

## 7. Testing Guidelines

### Test Structure

```lua
---Test suite for module_name
---@diagnostic disable: undefined-field
local module_name = require("markdown-plus.module_name")

describe("module_name", function()
  local buf

  -- Setup before each test
  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_set_current_buf(buf)
  end)

  -- Cleanup after each test
  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("function_name", function()
    it("should handle basic case", function()
      -- Arrange
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test content" })
      
      -- Act
      local result = module_name.function_name()
      
      -- Assert
      assert.are.equal(expected, result)
    end)
    
    it("should handle edge case", function()
      -- Test edge cases
    end)
    
    it("should handle error case", function()
      -- Test error handling
    end)
  end)
end)
```

### Test Location

- Tests mirror the structure of `lua/markdown-plus/`
- File naming: `spec/markdown-plus/<module>_spec.lua`
- Test environment: `spec/minimal_init.lua`

### Test Coverage Goals

- All public functions must have tests
- Test success cases and error cases
- Test edge cases (empty input, nil values, boundary conditions)
- Maintain 80%+ coverage (currently ~85%)

### Running Tests

```bash
# All tests (runs entire suite)
make test

# Specific test file
make test-file FILE=spec/markdown-plus/list_spec.lua

# Watch mode (auto-run on file change)
make test-watch
```

---

## 8. Release Process

This project uses [release-please](https://github.com/googleapis/release-please) for automated releases.

### Automated Workflow

1. Developer commits using conventional format (e.g., `feat: add feature`)
2. Release-please creates/updates a release PR automatically
3. Maintainer reviews and merges the release PR
4. Automated release happens:
   - GitHub release created
   - Tag created
   - LuaRocks package published
   - CHANGELOG.md updated

### Version Bumping

Based on conventional commit types:
- `feat:` → **minor** version bump (1.4.1 → 1.5.0)
- `fix:` → **patch** version bump (1.4.1 → 1.4.2)
- `feat!:` or `BREAKING CHANGE:` → **major** version bump (1.4.1 → 2.0.0)
- `chore:`, `docs:`, `style:`, `refactor:`, `test:` → no version bump

### Important Notes

- **CHANGELOG.md** is auto-generated - DO NOT edit manually
- Version numbers are managed automatically
- Breaking changes must be clearly marked with `!` or `BREAKING CHANGE:`

---

## 9. Important Files to Review First

When starting a new task, review these files in order:

1. **`lua/markdown-plus/init.lua`**
   - Understand plugin initialization
   - See how configuration is merged
   - Learn module loading order

2. **`lua/markdown-plus/types.lua`**
   - All type definitions
   - Configuration structure
   - API contracts

3. **`lua/markdown-plus/config/validate.lua`**
   - Valid configuration options
   - Validation rules
   - Error messages

4. **`README.md`**
   - User-facing features
   - Installation instructions
   - Quick start guide

5. **`CONTRIBUTING.md`**
   - Development guidelines
   - Code style requirements
   - Testing practices

6. **Relevant module in `lua/markdown-plus/<feature>/`**
   - Module-specific implementation
   - Feature keymaps
   - Internal patterns

---

## 10. Common Patterns

### Module Structure Template

```lua
-- Module description
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")

local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Setup module with configuration
---@param config markdown-plus.InternalConfig Plugin configuration
function M.setup(config)
  M.config = config or {}
end

---Enable features for current buffer
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end
  
  M.setup_keymaps()
end

---Set up keymaps for this module
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("ModuleAction"),
      fn = M.some_function,
      modes = "n",
      default_key = "<leader>ma",
      desc = "Description of action",
    },
  })
end

---Public function that does something
---@param input string The input parameter
---@return boolean success True if successful
function M.some_function(input)
  -- Implementation
end

return M
```

### Type Annotation Examples

```lua
-- Simple function
---Parse a markdown header line
---@param line string The line to parse
---@return number|nil level Header level (1-6) or nil if not a header
function M.parse_header(line)
  -- Implementation
end

-- Function with optional parameters
---Format table with options
---@param buf number Buffer handle
---@param opts? table Optional formatting options
---@return boolean success True if formatting succeeded
function M.format_table(buf, opts)
  opts = opts or {}
  -- Implementation
end

-- Function with multiple return values
---Get list info
---@param line string Line to parse
---@return boolean is_list True if line is a list
---@return string|nil list_type Type of list ("bullet", "ordered", "task")
---@return number|nil indent_level Indentation level
function M.get_list_info(line)
  -- Implementation
end

-- Type definition
---@class MyCustomType
---@field name string Required field
---@field value? number Optional field
---@field items string[] Array field
```

### Keymap Setup Pattern

Using `keymap_helper.lua` for consistent keymap management:

```lua
keymap_helper.setup_keymaps(M.config, {
  {
    plug = keymap_helper.plug_name("ActionName"),
    fn = M.function_to_call,
    modes = "n",  -- or {"n", "v"} for multiple modes
    default_key = "<leader>x",
    desc = "Description shown in which-key",
  },
  {
    plug = keymap_helper.plug_name("AnotherAction"),
    fn = M.another_function,
    modes = "i",
    default_key = "<C-x>",
    desc = "Another action description",
  },
})
```

### Validation Pattern

Using `vim.validate()` with error handling:

```lua
local ok, err = pcall(vim.validate, {
  name = { value, "string" },
  count = { count, "number" },
  optional_field = { optional, "table", true },  -- true = optional
})

if not ok then
  vim.notify(
    "markdown-plus: " .. tostring(err),
    vim.log.levels.ERROR
  )
  return false
end
```

---

## 11. Best Practices

### DO

- ✅ Write tests before implementing features (TDD)
- ✅ Use LuaCATS type annotations for all public functions
- ✅ Keep functions small and focused (single responsibility)
- ✅ Use descriptive variable and function names
- ✅ Validate user input with `vim.validate()`
- ✅ Make buffer-local keymaps with `hasmapto()` checks
- ✅ Use conventional commit format
- ✅ Run `make check` before committing
- ✅ Document complex algorithms with comments
- ✅ Follow existing code patterns in the module
- ✅ Add deprecation warnings with `vim.deprecate()` before removing APIs

### DO NOT

- ❌ Commit code that fails `make check`
- ❌ Remove existing functionality without deprecation warnings
- ❌ Use LuaJIT-only features without Lua 5.1 compatibility
- ❌ Create global normal-mode keymaps that conflict with common user mappings
- ❌ Edit CHANGELOG.md manually (it's auto-generated)
- ❌ Bypass configuration validation
- ❌ Use globals other than `vim`
- ❌ Make large refactors without comprehensive test coverage
- ❌ Add dependencies without strong justification
- ❌ Hardcode magic numbers or strings (use named constants)

### Performance Considerations

- Cache computed values (TOC, header indices) until buffer changes
- Use buffer-local autocmd groups with clear names
- Avoid excessive regex scans on every keypress
- Clear autocmds properly when disabling features
- Use `vim.schedule()` for non-blocking operations when appropriate

### Security Considerations

- Validate and sanitize all user input
- Be careful with `vim.cmd()` and shell commands
- Don't execute arbitrary code from configuration
- Sanitize file paths before opening

---

## 12. Troubleshooting

### Common Issues

**Tests not running:**
- Ensure plenary.nvim is installed
- Check Neovim version (0.11+ required)
- Verify minimal_init.lua is correctly set up

**Linting errors:**
- Run `make format` to auto-fix formatting
- Check `.luacheckrc` for allowed globals
- Ensure all variables are declared as `local`

**Type checking issues:**
- Review `.luarc.json` configuration
- Ensure Lua 5.1 compatibility
- Check LuaCATS annotation syntax

**Configuration not working:**
- Verify configuration in `types.lua`
- Check validation rules in `config/validate.lua`
- Test with both `setup()` and `vim.g.markdown_plus`

---

## 13. Quick Reference

### File Locations

| Purpose | Location |
|---------|----------|
| Plugin entry point | `lua/markdown-plus/init.lua` |
| Type definitions | `lua/markdown-plus/types.lua` |
| Config validation | `lua/markdown-plus/config/validate.lua` |
| Feature modules | `lua/markdown-plus/<feature>/init.lua` |
| Tests | `spec/markdown-plus/<feature>_spec.lua` |
| User documentation | `README.md`, `doc/markdown-plus.txt` |
| Developer docs | `CONTRIBUTING.md` |
| Config files | `.luacheckrc`, `.stylua.toml`, `.luarc.json` |

### Key Commands

```bash
make test              # Run all tests
make lint              # Lint code
make format            # Format code
make check             # Run all CI checks
make help              # Show all make targets
```

### Type Annotation Quick Reference

```lua
---@param name type Description
---@param optional? type Optional parameter
---@return type description
---@return type|nil description  -- Can be nil
---@class ClassName
---@field field_name type
---@field optional? type
---@type TypeName
```

---

## Appendix: External Resources

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [LuaCATS Annotations](https://luals.github.io/wiki/annotations/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Busted Testing Framework](https://olivinelabs.com/busted/)
- [StyLua Formatter](https://github.com/JohnnyMorganz/StyLua)
- [Luacheck Linter](https://github.com/lunarmodules/luacheck)

---

**Last Updated**: 2025-12-06

**Document Version**: 1.0.0

**For AI assistants**: This document provides comprehensive context about the markdown-plus.nvim codebase. Use it as a reference for understanding architecture, patterns, and development practices when working on this project.
