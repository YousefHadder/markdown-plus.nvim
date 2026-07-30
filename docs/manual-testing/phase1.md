# Manual Testing Guide — Issue #376 Phase 1

**Changes**: New `keymap_fallback` module; insert-mode `<BS>` now defers to pre-existing global/foreign mappings (mini.pairs etc.) and native Vim behavior instead of hand-rolled deletion. List-marker removal behavior unchanged.
**Date**: 2026-07-27
**Branch**: main (uncommitted working tree)
**Tracking doc**: `docs/plans/376-keymap-fallback-tracking.md` (internal, not published)

---

## Prerequisites

1. Neovim 0.11+ with your normal config, plus this working tree on `runtimepath` (e.g. `:set rtp+=/path/to/markdown-plus.nvim` in a scratch config, or point your plugin manager `dir =` at it). Make sure a _released_ copy of markdown-plus isn't loaded alongside.
2. **mini.pairs** (or another autopairs plugin mapping `<BS>` in insert mode) installed and enabled — needed for the interop cases. If you don't want a real plugin, put this simulated "foreign mapping" in your config instead:
   ```lua
   -- simulated mini.pairs-style global <BS>
   vim.keymap.set("i", "<BS>", function()
     vim.g.foreign_bs_fired = (vim.g.foreign_bs_fired or 0) + 1
     return "<BS>"
   end, { expr = true, desc = "test foreign BS" })
   ```
   Check hits with `:echo g:foreign_bs_fired`.
3. Open a markdown file: `nvim /tmp/376-test.md`.
4. `:checkhealth markdown-plus` — should be clean before starting.

`|` in the steps below marks the cursor position. All `<BS>` presses are in **insert mode** unless stated.

---

## Test Cases

### 1. Empty list item — marker removal unchanged

**Category**: Happy Path / Regression | **Priority**: P0

**Steps**:

1. Type a list: `- first item`, press Enter → new line reads `- `.
2. With cursor after the marker (`- |`), press `<BS>`.

**Expected Result**: List marker removed, line becomes empty (indent only). Foreign `<BS>` mapping does NOT fire for this press (`g:foreign_bs_fired` unchanged, or no pair behavior).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 2. Start of list content — marker removal keeps content

**Category**: Happy Path / Regression | **Priority**: P0

**Steps**:

1. Line: `- hello`, cursor at start of content (`- |hello`), insert mode.
2. Press `<BS>`.

**Expected Result**: Marker removed, line becomes `hello`, cursor before `h`. Foreign mapping does not fire.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 3. mini.pairs — paired deletion in plain text (the reported bug)

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. On a non-list line, in insert mode type `(` — autopairs gives `(|)`.
2. Press `<BS>`.

**Expected Result**: **Both** parens deleted (pair deletion works again). Before this fix only manual deletion happened.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 4. mini.pairs — paired deletion inside list item content

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Line: `- note `, cursor at end, insert mode, type `(` → `- note (|)`.
2. Press `<BS>`.

**Expected Result**: Both parens deleted → `- note `. (New: fallback also applies inside list _content_, not only outside lists.)

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 5. Plain text backspace — native behavior

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Non-list line `hello world`, cursor at end, insert mode.
2. Press `<BS>` three times.

**Expected Result**: `hello wo`. Nothing unusual — one char per press, no lag, cursor correct.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 6. NEW BEHAVIOR — col 0 of a list line joins with previous line

**Category**: Edge Case | **Priority**: P0

**Steps**:

1. Two lines:
   ```
   some text
   - item
   ```
2. Cursor at column 0 of `- item` (`|- item`), insert mode (`i` at line start).
3. Press `<BS>`.

**Expected Result**: Lines join → `some text- item`. **This was a silent no-op before Phase 1** — now it follows normal Vim `'backspace'` behavior. Confirm you're OK with this change.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 7. Respects your 'backspace' option

**Category**: Edge Case | **Priority**: P1

**Steps**:

1. `:set backspace=` (empty).
2. Insert mode at the start of any line with a line above; press `<BS>`.
3. Restore afterwards: `:set backspace=indent,eol,start`.

**Expected Result**: No join, no deletion past insert start — the option is honored (previously the plugin always deleted regardless).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 8. Buffer start — nothing to delete

**Category**: Edge Case | **Priority**: P1

**Steps**:

1. Cursor line 1, col 0 of the file, insert mode.
2. Press `<BS>`.

**Expected Result**: No error, no notification, nothing deleted.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 9. Unicode deletion

**Category**: Edge Case / Regression | **Priority**: P1

**Steps**:

1. Line: `- café`, cursor at end, insert mode.
2. Press `<BS>` once.

**Expected Result**: `- caf` — the whole `é` deleted in one press, no mojibake/half-character.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 10. Nested list marker removal

**Category**: Regression | **Priority**: P1

**Steps**:

1. Lines:
   ```
   - parent
     - child
   ```
2. On the child line, cursor at start of content (`  - |child`), press `<BS>`.

**Expected Result**: Marker removed → `  child` (indent preserved). Foreign mapping not fired.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 11. KNOWN LIMITATION — inside fenced code block, pairs NOT honored yet

**Category**: Edge Case | **Priority**: P1

**Steps**:

1. Create a fenced block and go inside:
   ````
   ```lua
   x = (|)
   ```
   ````
   (type the parens with autopairs active)
2. Press `<BS>`.


**Expected Result**: Only ONE paren deleted (raw native backspace) — the code-block path still bypasses foreign mappings. **This is expected until Phase 2.** Record here how disruptive this feels in practice.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 12. Pre-existing buffer-local <BS> mapping wins

**Category**: Regression | **Priority**: P1

**Steps**:

1. In a NEW markdown buffer, BEFORE the FileType autocmd runs is hard to arrange manually — instead: open any non-markdown buffer, run
   `:lua vim.keymap.set("i", "<BS>", function() vim.notify("mine!") end, { buffer = true })`
   then `:set filetype=markdown`.
2. Insert mode, press `<BS>`.

**Expected Result**: `mine!` notification — the plugin did not override your buffer-local mapping (unchanged pre-existing behavior).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 13. Lazy-loaded pairs plugin still found

**Category**: Edge Case | **Priority**: P1

**Steps**:

1. If mini.pairs is lazy-loaded (e.g. on `InsertEnter`): open the markdown file fresh, do NOT enter insert mode yet, then enter insert mode, type `(`, press `<BS>`.
2. If your pairs plugin loads eagerly: simulate instead — open the markdown buffer first, THEN define the simulated foreign mapping from Prerequisites, then test `<BS>` on a non-list line.

**Expected Result**: Foreign mapping honored even though it was created AFTER markdown-plus set up the buffer (resolution is per-keypress, not snapshotted).

**Result**: [x] PASS [ ] FAIL

**Notes**:

> Confirmed after clarification: mapping defined after buffer setup is still honored (per-keypress resolution).

---

### 14. Foreign mapping that errors — graceful degradation

**Category**: Error Handling | **Priority**: P1

**Steps**:

1. `:lua vim.keymap.set("i", "<BS>", function() error("boom") end, { desc = "broken foreign BS" })` (global).
2. In the markdown buffer, non-list line, insert mode, press `<BS>`.
3. Clean up: `:lua vim.keymap.del("i", "<BS>")`.

**Expected Result**: A `markdown-plus:`-prefixed error notification (no raw stack-trace crash, no stuck insert mode); the key still degrades to a plain backspace.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 15. Other list keys untouched

**Category**: Regression | **Priority**: P0

**Steps**:

1. On `- item`, press Enter at end of line → auto-continues `- `.
2. Press `<Tab>` on the new item → indents.
3. Press `<S-Tab>` → outdents.
4. Normal mode `o` on a list line → new list item below.

**Expected Result**: All list behaviors exactly as before Phase 1. (Note: `<CR>`/`<Tab>`/`<S-Tab>` still shadow cmp/pairs mappings — that's Phase 2, not a Phase 1 regression.)

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 16. Non-markdown buffers unaffected

**Category**: Regression | **Priority**: P0

**Steps**:

1. Open a `.lua` or `.txt` file, insert mode, use `<BS>` normally; with autopairs, type `(` then `<BS>`.

**Expected Result**: Identical to your normal (non-markdown) editing — plugin buffer-local maps absent (`:imap <BS>` shows no MarkdownPlus entry).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 17. Rapid/held backspace — performance

**Category**: Performance | **Priority**: P2

**Steps**:

1. In a large markdown file (a few hundred lines), insert mode at end of a long paragraph.
2. Hold `<BS>` for ~3 seconds.

**Expected Result**: Smooth continuous deletion, no visible lag or stutter (fallback resolution runs per keypress).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 18. Health + startup clean

**Category**: Regression | **Priority**: P2

**Steps**:

1. Fresh `nvim /tmp/376-test.md`, then `:checkhealth markdown-plus` and `:messages`.

**Expected Result**: Health OK, no new warnings/errors in messages.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

## Summary

**Overall Result**: [x] PASS [ ] FAIL
**Tested By**: YousefHadder (2026-07-27)
**General Notes**:

> (overall observations, concerns, follow-ups — especially: is the case-6 col-0 join acceptable, and how painful is the case-11 code-block limitation before Phase 2?)
