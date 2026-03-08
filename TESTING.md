# Manual Testing Guide

**Changes**: v2.0 Phase 0 + Phase 1 updates (explicit setup-only config, `<localleader>` default keymaps, keymap standardization).
**Date**: 2026-03-08
**Branch**: v2.0

---

## Prerequisites

- Neovim 0.11+ with this branch checked out.
- Plugin manager points to this local checkout/branch.
- Baseline plugin spec for normal tests:
  ```lua
  {
    "yousefhadder/markdown-plus.nvim",
    ft = "markdown",
    opts = {},
  }
  ```
- Set localleader explicitly before plugin setup (recommended):
  ```lua
  vim.g.maplocalleader = "\\"
  ```
- Open a fresh Neovim session before each major scenario.

---

## Test Cases

### 1. Explicit setup path works (baseline smoke)

**Category**: Happy Path
**Priority**: P0 — must pass

**Steps**:

1. Start Neovim with the baseline plugin spec (`opts = {}`).
2. Open a markdown file.
3. Run `:echo maparg('<localleader>mb', 'n')`.
4. Put cursor on a word and press `<localleader>mb`.

**Expected Result**: Mapping exists and toggles bold formatting on the target word/selection.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 2. Legacy `vim.g.markdown_plus` config is not used

**Category**: Regression
**Priority**: P0 — must pass

**Steps**:

1. Configure:
   ```lua
   vim.g.markdown_plus = { keymaps = { enabled = false } }
   ```
   and keep plugin spec `opts = {}`.
2. Start Neovim and open markdown.
3. Run `:echo maparg('<localleader>mb', 'n')`.

**Expected Result**: Mapping still exists (legacy `vim.g.markdown_plus` does not disable keymaps).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 3. No-setup scenario no longer auto-initializes plugin behavior

**Category**: Breaking Change / Regression
**Priority**: P0 — must pass

**Steps**:

1. Temporarily remove `opts = {}` (or explicit `config = function() require('markdown-plus').setup(...) end`) from plugin spec.
2. Start Neovim and open markdown.
3. Run `:echo maparg('<localleader>mb', 'n')`.
4. Try `<localleader>mb` on a word.

**Expected Result**: No markdown-plus default mappings are active until `setup()` is explicitly configured.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 4. `<localleader>` mapping replaces old `<leader>` mapping

**Category**: Regression
**Priority**: P0 — must pass

**Steps**:

1. Restore baseline spec with `opts = {}`.
2. Open markdown buffer.
3. Check:
   - `:echo maparg('<localleader>mb', 'n')`
   - `:echo maparg('<leader>mb', 'n')`

**Expected Result**: `<localleader>mb` exists; `<leader>mb` does not exist as default markdown-plus mapping.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 5. Custom localleader value works

**Category**: Edge Case
**Priority**: P1 — should pass

**Steps**:

1. Set `vim.g.maplocalleader = ","` before plugin setup.
2. Open markdown buffer.
3. Press `,mb` on a word.

**Expected Result**: Bold toggle works using the customized localleader key.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 6. Header keymaps migrated to localleader

**Category**: Regression
**Priority**: P1 — should pass

**Steps**:

1. Create markdown with multiple headers.
2. Press `<localleader>h+` and `<localleader>h-` on a header.
3. Press `<localleader>ht` to generate TOC.

**Expected Result**: Header promote/demote and TOC generation work via localleader mappings.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 7. Table keymap prefix default is `<localleader>t`

**Category**: Happy Path
**Priority**: P0 — must pass

**Steps**:

1. In markdown buffer, trigger table creation with `<localleader>tc`.
2. Fill prompt values.
3. Run `<localleader>tf` and `<localleader>tn`.

**Expected Result**: Table create/format/normalize operations execute from the localleader prefix.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 8. Table insert-mode navigation still works

**Category**: Regression
**Priority**: P1 — should pass

**Steps**:
| Header 1 | Header 2 | Header 3 |
| -------- | -------- | -------- |
| | | |
| | | |
| | | |

1. Create/open a markdown table.
2. Enter insert mode inside a cell.
3. Use `<A-h>`, `<A-l>`, `<A-j>`, `<A-k>` to navigate.
4. Try navigation outside table boundaries.

**Expected Result**: Moves between table cells when possible; falls back to normal cursor movement at boundaries.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 9. TOC window navigation keys work after keymap refactor

**Category**: Regression
**Priority**: P0 — must pass

**Steps**:

1. Create markdown with nested headers.
2. Open TOC window (`<localleader>hT`).
3. In TOC window, use:
   - `l` expand
   - `h` collapse
   - `<Enter>` jump
   - `?` help
   - `q` close

**Expected Result**: All TOC controls behave as documented; TOC remains navigable and closable.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 10. `keymaps.enabled = false` disables default mappings only

**Category**: Error Handling / Regression
**Priority**: P1 — should pass

**Steps**:

1. Configure:
   ```lua
   opts = {
     keymaps = { enabled = false },
   }
   ```
2. Open markdown and check `:echo maparg('<localleader>mb', 'n')`.
3. Manually map one `<Plug>` mapping:
   ```vim
   :nnoremap <buffer> <F6> <Plug>(MarkdownPlusBold)
   ```
4. Press `<F6>` on a word.

**Expected Result**: Default localleader mappings are absent, but `<Plug>` mappings still work when manually bound.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 11. Existing buffer-local user mapping is preserved

**Category**: Edge Case
**Priority**: P2 — nice to verify

**Steps**:

1. In markdown buffer, define:
   ```vim
   :nnoremap <buffer> <localleader>mb :echo "mine"<CR>
   ```
2. Re-run setup (restart Neovim is simplest).
3. Press `<localleader>mb`.

**Expected Result**: User buffer-local mapping remains intact and is not overwritten by plugin default mapping.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 12. Health check reports sane status

**Category**: Regression
**Priority**: P1 — should pass

**Steps**:

1. Start Neovim with baseline setup.
2. Run `:checkhealth markdown-plus`.
3. Review output for configuration and feature checks.

**Expected Result**: Health check runs without errors and reports active configuration/feature status.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 13. Cross-feature smoke after keymap migration

**Category**: Regression
**Priority**: P0 — must pass

**Steps**:

1. In one markdown file, exercise:
   - Format: `<localleader>mb`, `<localleader>mi`, `<localleader>mF`, `<localleader>me` (visual)
   - Code blocks: `<localleader>mc`, `<localleader>mC`, `]c`, `[c`
   - Links: `<localleader>ml`, `<localleader>me`
   - Quote: `<localleader>mq`
   - List checkbox: `<localleader>mx`
2. Repeat once in visual mode for one formatter and one link operation.

**Expected Result**: Features still work end-to-end under localleader mappings.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 14. Re-run checklist after each future phase

**Category**: Regression
**Priority**: P0 — must pass

**Steps**:

1. After each approved phase, re-run test cases 1, 4, 7, 9, and 13.
2. Mark results and add phase-specific observations in notes.

**Expected Result**: No regressions introduced across phase-to-phase implementation.

**Result**: [ ] PASS [ ] FAIL

**Notes**:

>

---

## Summary

**Overall Result**: [ ] PASS [ ] FAIL
**Tested By**:
**General Notes**:

>
