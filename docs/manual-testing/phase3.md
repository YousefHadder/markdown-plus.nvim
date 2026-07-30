# Manual Testing Guide — Issue #376 Phase 3

**Changes**: Normal-mode `o`/`O` on **non-list** lines now defer to your own `o`/`O` mapping (if any) or native Vim behavior via `keymap_fallback`, instead of a hand-rolled blank-line insert. Restores `'autoindent'`, `'formatoptions'` comment continuation, counts (`3o`), and user mappings. List-line behavior (marker continuation, smart outdent) unchanged.
**Date**: 2026-07-28
**Branch**: main (uncommitted working tree; Phases 1-2 committed as 74b3596, 1793cc1)
**Tracking doc**: `docs/plans/376-keymap-fallback-tracking.md` (internal, not published)

---

## Prerequisites

Same setup as previous phases: this working tree on `runtimepath`, `nvim /tmp/376-test.md`.

Optional foreign-mapping counter (normal mode this time):

```lua
_G.o_fired = 0
vim.keymap.set("n", "o", function()
  _G.o_fired = _G.o_fired + 1
  return "o"
end, { expr = true, desc = "test foreign o" })
```

Check with `:lua vim.print(_G.o_fired)`. Remove with `:lua vim.keymap.del("n", "o")`.

`|` marks cursor. Normal mode unless stated.

---

## Test Cases

### 1. `o` / `O` on list lines unchanged

**Category**: Regression | **Priority**: P0

**Steps**:


1. On `- item`, press `o` → new list item below, insert mode after marker. Escape.
2. Press `O` → list item above.
3. Numbered list: on `1. item`, press `o` → `2. ` and renumbering correct.

-
- item
-
**Expected Result**: Identical to before. Foreign `o` counter unchanged.

**Result**: [ ] PASS [x] FAIL

**Notes**:

> counter printed 1
---

### 2. `o` / `O` on non-list lines — native behavior

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Plain paragraph line, press `o` → type `x` → Escape. Then `O` → type `y` → Escape.

y
hello world
x
**Expected Result**: Line with `x` below, line with `y` above, insert mode entered each time — same as vanilla Vim.

**Result**: [x] PASS [ ] FAIL

**Notes**:

> counter printed 3
---

### 3. `'autoindent'` preserved on non-list `o`

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Indented non-list line `    some text`, cursor on it, press `o`, type `more`.

    some text
    more
**Expected Result**: New line is `    more` — indent kept. Before Phase 3: cursor forced to column 0.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 4. Count works: `3o` opens three lines

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Non-list line, press `3o`, type `x`, press Escape.


hello world
x
x
x

**Expected Result**: Three new lines each containing `x` (count applies when leaving insert mode — vanilla Vim behavior). Before Phase 3: one line only.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 5. Your own `o` mapping fires on non-list lines

**Category**: Happy Path | **Priority**: P1

**Steps**:

1. Install the counter mapping from Prerequisites.
2. Non-list line, press `o`, Escape. Check `:lua vim.print(_G.o_fired)` → increments.
3. List line `- item`, press `o`, Escape → counter does NOT increment (list logic wins).
4. Clean up the mapping.

- item
-
hello world

- item
-
**Expected Result**: Foreign map honored outside lists, list continuation preserved inside.

**Result**: [x] PASS [ ] FAIL

**Notes**:

> counter printed 2 then 3

---

### 6. Comment continuation (`'formatoptions'`)

**Category**: Edge Case | **Priority**: P2

**Steps**:

1. In a fenced ```lua block, line `-- comment`, press `o` (with your normal `formatoptions` including `o` flag).

```
-- comment

```
**Expected Result**: Whatever your vanilla Vim config does (comment leader continued if configured). Plugin no longer suppresses it on non-list lines.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 7. Code block `o` / `O` (regression from Phase 2)

**Category**: Regression | **Priority**: P1

**Steps**:

1. Inside a fenced code block, press `o`, Escape, `O`, Escape.

```



```
**Expected Result**: Plain lines opened, insert mode entered, no list logic. Same as Phase 2 testing.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 8. Non-markdown buffers unaffected

**Category**: Regression | **Priority**: P0

**Steps**:

1. `.lua`/`.txt` file: `o`, `O`, `3o` behave exactly as your normal config; `:nmap o` shows no MarkdownPlus entry.

**Expected Result**: Identical to normal editing.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 9. Health + startup clean

**Category**: Regression | **Priority**: P2

**Steps**:

1. Fresh `nvim /tmp/376-test.md`, `:checkhealth markdown-plus`, `:messages`.

**Expected Result**: Health OK, no new warnings/errors.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

## Known gaps (documented, not bugs to report)

- Count on a *list* line still creates one item (pre-existing, unchanged).
- Count is not re-applied on rare degradation paths (fallback bounce, erroring foreign map) — avoids double-apply risk.
- Foreign `o` mapping with a string rhs (`:nmap o ggo` style) loses the count; Lua-callback mappings (all real plugins) see it fine.

---

## Summary

**Overall Result**: [ ] PASS [ ] FAIL
**Tested By**:
**General Notes**:

>
