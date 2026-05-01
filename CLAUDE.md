# CLAUDE.md

## Project

**Stack**: Lua 5.1 / Neovim 0.11+ / Zero dependencies
**Architecture**: Feature-based modular plugin — 11 user-facing feature modules plus shared config/utils/treesitter infrastructure under `lua/markdown-plus/`
**Entry points**: `plugin/markdown-plus.lua` (load guard) → `lua/markdown-plus/init.lua` (setup + orchestration)
**Test command**: `make test` (Busted + plenary.nvim, 38 spec files)
**Build command**: `make check` (lint + format-check + test)

## Commands

```bash
make test              # Run all tests (plenary.nvim harness)
make test-file FILE=spec/markdown-plus/list_spec.lua
make lint              # luacheck
make format            # stylua (120 col, 2-space indent, double quotes)
make format-check      # Check only
make check             # Full CI: lint + format-check + test
```

## Key Directories

- `lua/markdown-plus/` — Core plugin code (74 Lua files across 14 module directories)
- `lua/markdown-plus/types.lua` — LuaCATS type definitions (update FIRST for new types)
- `lua/markdown-plus/config/validate.lua` — Schema-based config validation
- `lua/markdown-plus/utils.lua` — Shared utilities (cursor, line, buffer ops)
- `lua/markdown-plus/keymap_helper.lua` — Centralized `<Plug>` + default keymap registration
- `spec/markdown-plus/` — 38 Busted test suites
- `doc/markdown-plus.txt` — Vimdoc help file
- `plugin/markdown-plus.lua` — Load guard (no logic here)

## Feature Module Pattern

Most interactive features follow: `setup(config)` → `enable()` (per-buffer via FileType autocmd) → `setup_keymaps()`.
Features are conditionally loaded based on `config.features.*` flags in `init.lua`.
Features are mostly isolated; all depend on `utils.lua` and `keymap_helper.lua`.
Note: `utils/element.lua` has a soft cross-reference into `treesitter` and `code_block.parser`.
Table is the main special case: `init.lua` passes `config.table` to `table.setup()` and wires table keymaps directly without a `table.enable()` call.

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

- Framework: Busted via plenary.nvim (`spec/minimal_init.lua` bootstraps)
- Pattern: `describe()`/`it()` blocks, buffer fixtures in `before_each`
- 38 test files covering: config, utils, list (4 files: main + group_scanner/normal_handler/parser), format (3 files: main + escape/repeat), headers (5 files: main + manipulation/navigation + toc actions/render/state), links, smart_paste, table (6 files: main + creator/cell_ops/column_ops/row_ops/row_mapper), footnotes (7 files: main + insertion/navigation/window/line_parser/query/scanner), callouts, health, treesitter, images (2 files: main + insertion), code_block, thematic_break, quote

## Don't

- Edit CHANGELOG.md or rockspecs (automated)
- Remove APIs without `vim.deprecate()` warnings
- Bypass config validation
- Use LuaJIT-only features without gating
- Create global keymaps that conflict with common mappings
