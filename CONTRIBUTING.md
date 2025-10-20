# Contributing to markdown-plus.nvim

Thank you for your interest in contributing! 🎉

## How to Contribute

### Reporting Bugs
- Use the bug report template
- Provide clear steps to reproduce
- Include Neovim version and OS details
- Check if the issue is already reported

### Suggesting Features
- Use the feature request template
- Explain the use case clearly
- Describe expected behavior
- Consider backward compatibility

### Code Contributions

1. **Create a branch**: `git checkout -b feature/your-feature`
2. **Make your changes**
3. **Write tests**: Add tests for new functionality (see [Testing](#testing))
4. **Run quality checks**: `make test && make lint && make format`
5. **Commit**: Use clear, descriptive commit messages (see [Commit Messages](#commit-messages))
6. **Push**: `git push origin feature/your-feature`
7. **Open a Pull Request**: Use the PR template

**Note**: You can open issues and pull requests directly to this repository. No need to fork unless you prefer to work on your own copy first.

## Development Setup

### Prerequisites

```bash
# Install Lua linter
luarocks install luacheck

# Install Lua formatter (via Homebrew on macOS)
brew install stylua
# Or via Cargo
cargo install stylua

# Install plenary.nvim for testing
# Add to your plugin manager or:
git clone https://github.com/nvim-lua/plenary.nvim \
  ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim
```

### Project Structure

```
markdown-plus.nvim/
├── lua/markdown-plus/
│   ├── init.lua              # Plugin entry point
│   ├── types.lua             # Type definitions (LuaCATS)
│   ├── config/
│   │   └── validate.lua      # Configuration validation
│   ├── headers/
│   │   └── init.lua          # Headers and TOC functionality
│   ├── list/
│   │   └── init.lua          # List management
│   ├── format/
│   │   └── init.lua          # Text formatting
│   ├── links/
│   │   └── init.lua          # Link operations
│   └── utils.lua             # Utility functions
├── spec/
│   ├── minimal_init.lua      # Test environment setup
│   └── markdown-plus/        # Test suites
│       ├── config_spec.lua
│       ├── utils_spec.lua
│       ├── list_spec.lua
│       └── headers_spec.lua
└── plugin/
    └── markdown-plus.lua     # Auto-command setup
```

## Code Style

### Lua Style Guide
- **Formatting**: We use StyLua with 120 char width, 2-space indent
- **Naming**: Use `snake_case` for functions and variables
- **Globals**: Only use `vim` global; define all other vars as `local`
- **Comments**: Document complex logic and all public APIs

### Type Annotations
- Use LuaCATS annotations for all public functions
- Document parameters with `@param name type description`
- Document return values with `@return type description`
- Define types in `lua/markdown-plus/types.lua`

Example:
```lua
---Parse a markdown header line
---@param line string The line to parse
---@return table|nil header_info Table with level and text, or nil if not a header
function M.parse_header(line)
  -- Implementation
end
```

## Testing

### Writing Tests

Tests are written using [Busted](https://olivinelabs.com/busted/) with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

#### Test Structure
```lua
---Test suite for your module
---@diagnostic disable: undefined-field
local your_module = require("markdown-plus.your_module")

describe("your module", function()
  -- Setup before each test
  before_each(function()
    -- Create test buffer
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
    it("does something", function()
      -- Test implementation
      assert.are.equal(expected, actual)
    end)
  end)
end)
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=spec/markdown-plus/your_spec.lua

# Watch for changes and auto-test (requires 'entr')
make test-watch

# Run linter
make lint

# Format code
make format

# Check formatting without modifying
make format-check
```

### Test Coverage Goals
- All public functions should have tests
- Test both success and error cases
- Test edge cases (empty input, nil values, etc.)
- Aim for 100% test success rate

## Quality Checks

Before submitting a PR, ensure:

```bash
# All tests pass
make test
# Expected: 34/34 tests passing

# No linting errors
make lint
# Expected: 0 warnings / 0 errors

# Code is properly formatted
make format-check
# Expected: All files pass
```

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples
```
feat(headers): add support for setext headers

fix(list): correct variable reference in parse_list_line

test(config): add validation test cases

docs(readme): update development section with testing info
```

## Pull Request Guidelines

### Before Submitting
- [ ] All tests pass (`make test`)
- [ ] Code is linted (`make lint`)
- [ ] Code is formatted (`make format`)
- [ ] Added tests for new functionality
- [ ] Updated documentation if needed
- [ ] Updated CHANGELOG.md
- [ ] No breaking changes (or clearly documented)

### PR Description
- Clearly describe what the PR does
- Reference any related issues
- Include screenshots/GIFs for UI changes
- List any breaking changes
- Note any new dependencies

### Code Review
- Be open to feedback
- Respond to comments promptly
- Make requested changes
- Keep the PR focused and atomic

## Documentation

### Code Documentation
- Add LuaCATS type annotations to all public functions
- Document complex algorithms
- Explain non-obvious behavior
- Keep comments up-to-date

### User Documentation
Update these files as needed:
- `README.md` - User-facing features and usage
- `CHANGELOG.md` - All changes, following Keep a Changelog format
- `doc/markdown-plus.txt` - Vim help documentation

## CI/CD Pipeline

Our CI runs on every push and PR:
- **Tests**: Matrix testing on Ubuntu/macOS with Neovim stable/nightly
- **Linting**: Luacheck validation
- **Formatting**: StyLua compliance check
- **Documentation**: TODOs and markdown validation

All checks must pass before merging.

## Questions?

- Open an issue for discussion before starting major changes
- Ask questions in draft PRs
- Join discussions in existing issues

## Code of Conduct

Please be respectful and constructive. We're all here to make this plugin better!

## Recognition

Contributors will be listed in:
- GitHub contributors page
- Release notes for their contributions

Thank you for contributing! 🙏
