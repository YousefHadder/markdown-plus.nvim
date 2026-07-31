# Copilot Instructions: markdown-plus.nvim

## Repository Overview

**Plugin Name:** markdown-plus.nvim  
**Purpose:** Modern, feature-rich Markdown editing for Neovim

### Core Features
Eleven user-facing feature modules, each toggleable via `features.*`:
- **list** — auto-continue, indent/outdent, renumbering, checkboxes, list-type toggling
- **format** — bold, italic, strikethrough, inline code, highlight, escape, clear formatting
- **headers** — navigate, promote/demote, ATX/setext toggle, generate/update GitHub-compatible TOC
- **links** — insert, edit, convert inline/reference, auto-link URLs, smart paste
- **table** — create, format, navigate, row/column ops, cell editor, CSV conversion
- **footnotes** — insert, edit, delete, navigate, footnotes window
- **code_block** — insert/wrap, navigate (`]b`/`[b`), change language
- **callouts** — GFM admonitions, cycle types, custom types
- **quote** — toggle blockquote markers
- **images** — insert/edit image syntax
- **thematic_break** — insert and cycle horizontal-rule styles

### Architecture
- `lua/markdown-plus/` - Core modules (83 Lua files: 6 at root + 77 across 14 directories):
  - Feature modules: list/, format/, headers/, links/, table/, footnotes/, callouts/, quote/, images/, code_block/, thematic_break/
  - Shared: utils/ (buffer, text, selection, element, html), treesitter/, config/
  - Root: init.lua, types.lua, utils.lua, keymap_helper.lua, keymap_fallback.lua, health.lua
- `plugin/markdown-plus.lua` - Entry point with lazy initialization guard
- `spec/` - 49 Busted test suites, plus `spec/helpers/` and `spec/minimal_init.lua`
- `test/e2e/` - Separate end-to-end keymap harness (real keypresses, isolated Neovim)
- `scripts/` - `test` (coverage enforcement), `run-e2e.sh` (isolated e2e runner)
- `doc/` - Vimdoc help files
- `docs/wiki/` - Published wiki source (synced by wiki-sync.yml)
- `rockspecs/` - LuaRocks package specifications

### Quality Tooling
- **Type annotations:** LuaCATS in types.lua & all modules
- **Linting:** .luacheckrc
- **Formatting:** .stylua.toml
- **Type checking:** .luarc.json (Lua 5.1 runtime)
- **Testing:** Busted + Plenary (49 spec files, ~85% coverage)

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
   - Extend the schema in `config/validate.lua`; it rejects unknown fields and returns user-facing error messages
   - Use `require('markdown-plus').setup(opts)` (v2.0 removed `vim.g.markdown_plus`)
   - Provide helpful error messages for invalid configurations

3. **Keymaps**
   - Expose ALL functionality through `<Plug>` mappings
   - Use `keymap_helper.lua` for defaults; it checks existing buffer-local mappings with `maparg()` before setting them
   - `<Plug>` mappings are global and registered once per mode; user-facing defaults are buffer-local and tracked so teardown removes only our own
   - Keys other plugins commonly own (`<CR>`, `<BS>`, `<Tab>`, `<S-Tab>`, `<A-CR>`, `o`/`O`, `<A-h/j/k/l>`) must hand the press back via `keymap_fallback.run()` when outside markdown-plus's own context — never reimplement native behavior, and never feed a key that routes back into our own `<Plug>`
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
make test-coverage     # Run tests with coverage threshold checks (85% overall, 80% critical)
make test-file         # Run tests for a specific file (set FILE=path/to/spec.lua)
make test-watch        # Run tests in watch mode
make test-e2e          # Real keypresses through real keymaps in an isolated Neovim

# Code Quality
make lint              # luacheck on lua/ spec/ test/
make format            # stylua on lua/ spec/ plugin/ test/
make format-check      # Check formatting without modifying files

# Combined
make check             # lint + format-check + test (does NOT include test-e2e)
```

Coverage enforcement lives in `scripts/test`, gated by `MARKDOWN_PLUS_ENFORCE_COVERAGE=1`.
Critical files held to 80%: `headers/init.lua`, `headers/toc.lua`, `list/init.lua`, `links/http_fetch.lua`.
CI is a reused workflow (`folke/github/.github/workflows/ci.yml`), so most checks are not defined in this repo.

### Best Practices Checklist

#### Type Safety
- [ ] Add LuaCATS annotations for all new/modified functions
- [ ] Update `types.lua` if adding new config or API types
- [ ] Verify Lua 5.1 compatibility (no LuaJIT-only code)

#### Configuration
- [ ] Extend `config/validate.lua` schema for all user-facing options
- [ ] Preserve unknown-field rejection and clear validation messages
- [ ] Update config schema in multiple files (types, validate, docs, tests)
- [ ] Provide sensible defaults

#### Keymaps
- [ ] Create `<Plug>` mappings for new interactive features
- [ ] Use `keymap_helper.lua` so defaults respect existing buffer-local mappings
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
5. **Request permission to commit**

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
- Table is special: `init.lua` passes `config.table` to `table.setup()` and installs table keymaps directly without `table.enable()`

### Versioning (SemVer)
- **Patch:** Bug fixes, test improvements, internal refactors (no API changes)
- **Minor:** New features, new config keys (non-breaking), new mappings
- **Major:** Breaking changes, removal of deprecated APIs, structural changes

---

## Quick Reference

### File Hotspots
- `lua/markdown-plus/init.lua` - Core setup + config merge
- `lua/markdown-plus/types.lua` - Type definitions (extend here first)
- `lua/markdown-plus/config/validate.lua` - Config validation
- `lua/markdown-plus/utils.lua` - Shared utilities
- `lua/markdown-plus/keymap_helper.lua` - `<Plug>` + default keymap registration
- `lua/markdown-plus/keymap_fallback.lua` - Hands keys back to other plugins
- `plugin/markdown-plus.lua` - Initialization entry point
- `spec/markdown-plus/*` - Test files

### Gotchas
- `docs/*` is gitignored except `docs/wiki/` and `docs/manual-testing/` — new files elsewhere under `docs/` are silently untracked
- `lint` covers `lua/ spec/ test/`; `format`/`format-check` also cover `plugin/`
- `spec/` (Busted) and `test/e2e/` (real keypresses) are different harnesses; `make check` runs only the former
- Reset module state in `before_each`/`after_each` — plenary never reaches an event-loop turn between `it` blocks, so `vim.schedule`-released state leaks between tests
- Requires are mixed by design: shared infra (`utils`, `treesitter`) at module top, feature/sibling modules required inside functions to break cycles
- Use `vim.notify("markdown-plus: ...")` for user-facing errors; the only `error(`-shaped calls in `lua/` are `health.error()` (vim.health API)

### Testing Coverage
49 spec files, ~85% overall. Covered areas: config merging & validation, utils, treesitter,
health, keymap fallback & plugin interop, and all 11 feature modules — list (10 specs),
table (9), footnotes (7), headers (6), format (3), images (2), links, smart paste,
callouts, quote, code_block, thematic_break.
