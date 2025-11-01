# Copilot Instructions: markdown-plus.nvim

## Repository Overview

**Plugin Name:** markdown-plus.nvim  
**Purpose:** Modern, feature-rich Markdown editing for Neovim

### Core Features
- **List management:** Auto-continue, indent/outdent, renumbering, checkbox support
- **Text formatting:** Bold, italic, strikethrough, inline code, clear formatting
- **Headers & TOC:** Navigate, promote/demote, generate/update GitHub-compatible TOC
- **Link management:** Insert, edit, convert inline/reference, auto-link URLs

### Architecture
- `lua/markdown-plus/` - Core modules (init.lua, list/, format/, headers/, links/, utils.lua, types.lua, config/validate.lua)
- `plugin/markdown-plus.lua` - Entry point with lazy initialization guard
- `spec/` - Busted test suites
- `doc/` - Vimdoc help files
- `rockspecs/` - LuaRocks package specifications

### Quality Tooling
- **Type annotations:** LuaCATS in types.lua & all modules
- **Linting:** .luacheckrc
- **Formatting:** .stylua.toml
- **Type checking:** .luarc.json (Lua 5.1 runtime)
- **Testing:** Busted + Plenary (~85% coverage)

---

## Development Instructions

### Before Starting Any Work

1. **Understand the task scope** - Read related code and documentation first
2. **Check existing tests** - Run `make test` to ensure everything is green
3. **Verify code quality** - Run `make lint` and `make format-check`
4. **Plan the changes** - Break down the task into small, atomic steps

### Development Workflow

1. **Type Safety First**
   - Add LuaCATS annotations (`@class`, `@param`, `@return`) for all new functions
   - Update `lua/markdown-plus/types.lua` for new configuration or API types
   - Maintain Lua 5.1 compatibility (no LuaJIT-only features)
   - Keep `.luarc.json` configured correctly

2. **Configuration Changes**
   - New config keys must be added to: `types.lua`, `config/validate.lua`, README, vimdoc, and tests
   - Use `vim.validate()` wrapped with `pcall` for validation
   - Support both `require('markdown-plus').setup(opts)` AND `vim.g.markdown_plus`
   - Provide helpful error messages for invalid configurations

3. **Keymaps**
   - Expose ALL functionality through `<Plug>` mappings
   - Use `hasmapto()` before setting default keymaps
   - Never create global normal-mode maps that conflict with common user mappings
   - Keep keymaps buffer-local and properly scoped

4. **Testing Requirements**
   - ALL new features MUST have accompanying tests
   - Add unit tests for individual functions
   - Consider integration tests for feature interactions
   - Maintain minimum 80% coverage (currently ~85%)
   - Run `make test` before committing

5. **Documentation**
   - Update both README.md AND doc/markdown-plus.txt
   - Keep examples synchronized between both files
   - Document any new configuration options with examples
   - Add troubleshooting information if relevant

6. **Code Quality**
   - Max line length: 120 characters
   - Run `make format` to apply stylua formatting
   - Keep functions small and focused
   - Prefer small helpers in `utils.lua` for reused code
   - Use descriptive variable and function names

### Makefile Targets

```bash
# Testing
make test              # Run all tests
make test-file         # Run tests for a specific file (set FILE=path/to/spec.lua)
make test-watch        # Run tests in watch mode

# Code Quality
make lint              # Run luacheck
make format            # Format code with stylua
make format-check      # Check formatting without modifying files

# Combined
make check             # Run lint + format-check + test
```

### Best Practices Checklist

#### Type Safety
- [ ] Add LuaCATS annotations for all new/modified functions
- [ ] Update `types.lua` if adding new config or API types
- [ ] Verify Lua 5.1 compatibility (no LuaJIT-only code)

#### Configuration
- [ ] Validate all user input with `vim.validate()`
- [ ] Add unknown field warnings
- [ ] Update config schema in multiple files (types, validate, docs, tests)
- [ ] Provide sensible defaults

#### Keymaps
- [ ] Create `<Plug>` mappings for new interactive features
- [ ] Check `hasmapto()` before setting defaults
- [ ] Use buffer-local keymaps
- [ ] Document all keymaps in vimdoc

#### Testing
- [ ] Write tests for new functionality
- [ ] Include positive test cases and edge cases
- [ ] Verify tests pass: `make test`
- [ ] Maintain or improve coverage

#### Documentation
- [ ] Update README.md
- [ ] Update doc/markdown-plus.txt
- [ ] Synchronize examples between both
- [ ] Add troubleshooting info if needed

#### Code Quality
- [ ] Run `make lint` - must pass
- [ ] Run `make format` - apply formatting
- [ ] Keep functions focused and small
- [ ] Follow existing code patterns

#### Version Control
- [ ] Create atomic commits (one logical change per commit)
- [ ] Write simple, concise one-line commit messages (no detailed descriptions)
- [ ] Update CHANGELOG.md with changes
- [ ] **ASK PERMISSION before committing or pushing**

### Common Patterns

#### Adding a New Feature
1. Update `types.lua` with type definitions
2. Update `config/validate.lua` with validation rules
3. Implement the feature in appropriate module
4. Create `<Plug>` mappings
5. Add tests in `spec/markdown-plus/`
6. Update README and vimdoc
7. Run `make check` to verify
8. **Request permission to commit**

#### Fixing a Bug
1. Add a failing test that reproduces the bug
2. Fix the bug
3. Verify the test passes
4. Run `make check`
5. Update CHANGELOG.md
6. **Request permission to commit**

### Important Constraints

#### DO NOT
- Remove existing functionality without deprecation warnings
- Introduce LuaJIT-only code without gating and documentation
- Bypass validation for user configuration
- Commit large refactors without test coverage
- Create multiple top-level commands (prefer `<Plug>` or subcommands)
- Write verbose multi-line commit messages (keep it one line)
- **Commit or push without explicit user permission**

#### DO
- Maintain backward compatibility
- Add deprecation warnings via `vim.deprecate()` before removing APIs
- Keep changes surgical and focused
- Write tests before implementation when fixing bugs
- Update all related documentation in the same changeset
- Write concise one-line commit messages in conventional commit format
- **Always ask permission before committing or pushing**

### Performance & Safety
- Cache computed values (TOC, header indices) until buffer changes
- Use buffer-local autocmd groups with clear names
- Avoid excessive regex scans on every keypress
- Clear autocmds properly when disabling features

### Versioning (SemVer)
- **Patch:** Bug fixes, test improvements, internal refactors (no API changes)
- **Minor:** New features, new config keys (non-breaking), new mappings
- **Major:** Breaking changes, removal of deprecated APIs, structural changes

Always update CHANGELOG.md with: Added / Changed / Fixed / Deprecated sections

---

## Quick Reference

### File Hotspots
- `lua/markdown-plus/init.lua` - Core setup + config merge
- `lua/markdown-plus/types.lua` - Type definitions (extend here first)
- `lua/markdown-plus/config/validate.lua` - Config validation
- `lua/markdown-plus/utils.lua` - Shared utilities
- `plugin/markdown-plus.lua` - Initialization entry point
- `spec/markdown-plus/*` - Test files

### Testing Coverage
✅ Config merging & validation  
✅ Utility helpers  
✅ List management  
✅ Headers & TOC  
✅ Text formatting  
✅ Link management