# CLAUDE.md

## Project

**Stack**: Lua 5.1 / Neovim 0.11+ / Zero dependencies
**Architecture**: Feature-based modular plugin — 11 user-facing feature modules plus shared config/utils/treesitter infrastructure under `lua/markdown-plus/`
**Entry points**: `plugin/markdown-plus.lua` (load guard) → `lua/markdown-plus/init.lua` (setup + orchestration)
**Test command**: `make test` (Busted + plenary.nvim, 49 spec files)
**Build command**: `make check` (lint + format-check + test)

## Commands

```bash
make test              # Run all tests (plenary.nvim harness)
make test-file FILE=spec/markdown-plus/list_spec.lua
make test-coverage     # Coverage thresholds: 85% overall, 80% critical files
make test-e2e          # Real keypresses through real keymaps in an isolated Neovim
make lint              # luacheck on lua/ spec/ test/
make format            # stylua on lua/ spec/ plugin/ test/ (120 col, 2-space, double quotes)
make format-check      # Check only
make check             # lint + format-check + test — does NOT include test-e2e
```

Coverage enforcement lives in `scripts/test`, gated by `MARKDOWN_PLUS_ENFORCE_COVERAGE=1`.
Critical files held to 80%: `headers/init.lua`, `headers/toc.lua`, `list/init.lua`, `links/http_fetch.lua`.

## Key Directories

- `lua/markdown-plus/` — Core plugin code (83 Lua files: 6 at root + 77 across 14 module dirs)
- `lua/markdown-plus/types.lua` — LuaCATS type definitions (update FIRST for new types)
- `lua/markdown-plus/config/validate.lua` — Schema-based config validation
- `lua/markdown-plus/utils.lua` — Facade over `utils/` (buffer, text, selection, element, html)
- `lua/markdown-plus/keymap_helper.lua` — Centralized `<Plug>` + default keymap registration
- `lua/markdown-plus/keymap_fallback.lua` — Hands keys back to other plugins outside our context
- `spec/markdown-plus/` — 49 Busted test suites (plus `spec/helpers/`, `spec/minimal_init.lua`)
- `test/e2e/` — Separate e2e harness (real keypresses, isolated Neovim) — not Busted
- `scripts/` — `test` (coverage enforcement), `run-e2e.sh` (isolated e2e runner)
- `doc/markdown-plus.txt` — Vimdoc help file
- `docs/wiki/` — Published wiki source (synced by `wiki-sync.yml`)
- `plugin/markdown-plus.lua` — Load guard (no logic here)

## Feature Module Pattern

Most interactive features follow: `setup(config)` → `enable()` (per-buffer via FileType autocmd) → `setup_keymaps()`.
Features are conditionally loaded based on `config.features.*` flags in `init.lua`.
Features are mostly isolated; all depend on `utils.lua` and `keymap_helper.lua`.
Note: `utils/element.lua` has a soft cross-reference into `treesitter` and `code_block.parser`.
Table is the main special case: `init.lua` passes `config.table` to `table.setup()` and wires table keymaps directly without a `table.enable()` call.

Keys other plugins commonly own — `<CR>`, `<BS>`, `<Tab>`, `<S-Tab>`, `<A-CR>`, `o`/`O`, `<A-h/j/k/l>` — are only acted on inside markdown-plus's own context. Everywhere else `keymap_fallback.run()` resolves buffer-local → global → raw key and hands the press back. Never feed a key that routes back into our own `<Plug>`; that bounces.

## Conventions

- **LuaCATS annotations required** on all functions (`@class`, `@param`, `@return`)
- **`<Plug>` mappings mandatory** for all interactive features; buffer-local defaults
- **Config changes touch 6 files**: types.lua, init.lua defaults, validate.lua, README, vimdoc, tests
- **TDD for bugs**: write failing test first, then fix
- **Conventional Commits** enforced: `feat(scope):`, `fix(scope):`, etc.
- **CHANGELOG.md is auto-generated** by release-please — never edit manually
- **Ask permission** before committing or pushing
- Error handling: `pcall` for unsafe ops, `vim.notify()` for user errors (no `error()`/`assert()`)
- Constants: `UPPER_SNAKE_CASE`; private module state: plain `local` (no underscore prefix on helpers)

## Config Flow

```
require("markdown-plus").setup(opts)
  → validate via config/validate.lua (schema-based, rejects unknown fields)
  → vim.tbl_deep_extend("force", defaults, opts)
  → conditionally require feature modules (features.* flags)
  → feature.setup(config) for each enabled feature
  → FileType autocmd → feature.enable() per buffer → buffer-local keymaps
```

## Testing

- Framework: Busted via plenary.nvim (`spec/minimal_init.lua` bootstraps; finds plenary via `PLENARY_DIR` or common plugin-manager paths)
- Pattern: `describe()`/`it()` blocks, buffer fixtures in `before_each`
- Helpers in `spec/helpers/`: `mocks.lua` (stub `vim.notify` / `vim.ui.select` / `vim.fn.input`), `insert_mode.lua`, `async.lua`
- Reset module state explicitly in `before_each`/`after_each` — plenary never reaches an event-loop turn between `it` blocks, so `vim.schedule`-released state leaks between tests
- 49 spec files. Densest areas: list (10), table (9), footnotes (7), headers (6), format (3), images (2); plus `keymap_fallback_spec.lua` and `interop_recipes_spec.lua`
- `test/e2e/` is a separate harness (`make test-e2e`) driving real keys through real buffer-local keymaps; not run by `make check` or CI

## Gotchas

- `docs/*` is gitignored except `docs/wiki/` and `docs/manual-testing/` — new files elsewhere under `docs/` are silently untracked
- `lint` covers `lua/ spec/ test/`; `format`/`format-check` also cover `plugin/`
- Requires are mixed by design: shared infra (`utils`, `treesitter`) at module top, feature/sibling modules required inside functions to break cycles — follow the surrounding file
- The only `error(`-shaped calls in `lua/` are `health.error()` (vim.health API); runtime code uses `vim.notify("markdown-plus: ...")`
- CI is a reused workflow (`folke/github/.github/workflows/ci.yml`), so most checks are not defined in this repo

## Don't

- Edit CHANGELOG.md or rockspecs (automated)
- Remove APIs without `vim.deprecate()` warnings
- Bypass config validation
- Use LuaJIT-only features without gating
- Create global keymaps that conflict with common mappings
