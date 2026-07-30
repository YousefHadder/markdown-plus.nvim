# Manual Testing Guide — Issue #376 Phase 4 (final)

**Changes**: Public API `in_list_context(kind)`; `<A-CR>` now defers to your mappings on non-list lines (last hand-rolled key); `<Plug>` registration state reset on plugin teardown; new "Interop" docs in README + vimdoc.
**Date**: 2026-07-29
**Branch**: main (uncommitted working tree; Phases 1-3 committed as 74b3596, 1793cc1, d83e4ed)
**Tracking doc**: `docs/plans/376-keymap-fallback-tracking.md` (internal, not published)

---

## Prerequisites

Same as previous phases. `nvim /tmp/376-test.md`.

---

## Test Cases

### 1. Public API — list context queries

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Cursor on `- item` line, run:
   `:lua print(require("markdown-plus").in_list_context())` → expect `true`
2. Cursor on a plain paragraph line, same command → expect `false`
3. On the list line: `:lua print(require("markdown-plus").in_list_context("indent"))` → `true`;
   `"backspace"` kind is **marker-zone only** (true only where `<BS>` would remove the marker):
   cursor on the first content char (`- |item`, normal-mode cursor on `i`) →
   `:lua print(require("markdown-plus").in_list_context("backspace"))` → `true`;
   cursor mid-content or at col 0 → `false` (correct — `<BS>` defers there).
4. Bad kind: `:lua print(require("markdown-plus").in_list_context("bogus"))` → error notification + `false`, no crash.

- item
**Expected Result**: As above; buffer unchanged by any call.

**Result**: [x] PASS [ ] FAIL

**Notes**:

> step 3 second command gave false instead of true on a list line
> RESOLVED: guide expectation was stale — "backspace" kind is marker-zone-only after review
> blocker fix; false mid-content/col-0 is correct. Spec-covered (13/13 in list_context_spec).

---

### 2. `<A-CR>` on non-list line defers

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Non-list line, insert mode, press `<A-CR>` (terminal permitting; if your terminal swallows Alt+Enter, run `:lua vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<A-CR>", true, false, true), "m", false)` instead).

hello world
**Expected Result**: Plain newline via native behavior / your own `<A-CR>` mapping if you have one. (Before: hand-rolled split with cursor forced to column 0.)

**Result**: [x] PASS [ ] FAIL

**Notes**:

> failed with error [Copilot.lua] 'filetype' markdown rejected by internal_filetypes[markdown]
> RESOLVED — ACCEPTED as correct interop: copilot.lua maps global insert <M-CR> (panel.open)
> and disables markdown by default; it logs the error itself and consumes the key. Identical
> to vanilla nvim without markdown-plus. Pre-Phase-4 our buffer-local <A-CR> masked copilot's
> key — that masking was the #376 bug class. User remedies documented in interop docs
> (remap copilot panel.open, or copilot filetypes = { markdown = true }).


---

### 3. `<A-CR>` list behavior unchanged

**Category**: Regression | **Priority**: P0

**Steps**:

1. On `- some item text`, cursor mid-content, insert mode, press `<A-CR>`.

- some
  item text
**Expected Result**: Content continuation exactly as before Phase 4 (continuation line under the item, no new marker).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 4. Teardown/re-setup clean

**Category**: Regression | **Priority**: P1

**Steps**:

1. `:lua require("markdown-plus").teardown()` (if teardown is exposed; else skip)
2. `:lua require("markdown-plus").setup({})`, reopen the markdown file.
3. `:imap <CR>` → MarkdownPlus mapping present again; keys behave normally.

**Expected Result**: Second setup re-registers all defaults, no errors.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 5. Docs render

**Category**: Docs | **Priority**: P1

**Steps**:

1. `:helptags ALL` then `:help markdown-plus-interop`, `:help markdown-plus-recipes`, `:help markdown-plus.list.in_list_context`.
2. Skim README "Interop with completion/pairs plugins" section — recipes look right, match vimdoc.

**Expected Result**: All tags resolve; recipes consistent between files.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 6. Whole-surface smoke (regression)

**Category**: Regression | **Priority**: P0

**Steps**:

1. Quick pass with your real config: lists (`<CR>` continue, `<Tab>`/`<S-Tab>` indent, `<BS>` marker removal, `o`/`O`, checkboxes), pairs in and out of code fences, `3o`, blink/copilot `<Tab>` — no freezes, no surprises.

**Expected Result**: Everything from Phases 1-3 still good.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

## Summary

**Overall Result**: [ ] PASS [ ] FAIL
**Tested By**:
**General Notes**:

>
