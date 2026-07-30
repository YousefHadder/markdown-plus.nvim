# Manual Testing Guide — Issue #376 Phase 2

**Changes**: `<CR>`, `<Tab>`, `<S-Tab>` non-list paths and the code-block fall-through (`skip_in_codeblock`) now defer to your real mappings (cmp/blink, mini.pairs, snippets) or native Vim behavior via `keymap_fallback`, instead of hand-rolled/raw-key behavior. Fixes the Phase-1 code-block limitation (`<BS>` pairs now work inside fences). `o`/`O` inside code blocks resolve normal-mode foreign mappings.
**Date**: 2026-07-28
**Branch**: main (uncommitted working tree; Phase 1 committed as 74b3596)
**Tracking doc**: `docs/plans/376-keymap-fallback-tracking.md` (internal, not published)

---

## Prerequisites

Same setup as Phase 1 (Phase 1 (`phase1.md`)): this working tree on `runtimepath`, mini.pairs (or simulated foreign mapping) active, `nvim /tmp/376-test.md`.

Optional counters for keys beyond `<BS>` (run in Neovim before testing):

```lua
-- WARNING: these are *global* mappings and they overwrite whatever your completion /
-- snippet plugin already mapped for these keys. blink.cmp and copilot.lua re-apply their
-- own buffer-local mappings on InsertEnter, so restart Neovim when you are done counting.
_G.foreign_fired = {}
for _, key in ipairs({ "<CR>", "<Tab>", "<S-Tab>" }) do
  vim.keymap.set("i", key, function()
    -- vim.g returns a copy, so the counters must live in a plain Lua table
    _G.foreign_fired[key] = (_G.foreign_fired[key] or 0) + 1
    return key
  end, { expr = true, desc = "test foreign " .. key })
end
```


Check with `:lua vim.print(_G.foreign_fired)`. NOTE: if you use nvim-cmp/blink.cmp, its own `<CR>`/`<Tab>` config plays the foreign-mapping role — you can test with your real completion plugin instead of counters.

`|` marks cursor. Insert mode unless stated.

---

## Test Cases

### 1. List auto-continue unchanged

**Category**: Regression | **Priority**: P0

**Steps**:

1. Line `- item`, cursor at end, press `<CR>`.
2. On the new `- ` line, press `<CR>` again.

- item

**Expected Result**: First press auto-continues (`- `), second press removes the empty marker and breaks out. Foreign `<CR>` counter unchanged for both presses.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 2. List indent/outdent unchanged

**Category**: Regression | **Priority**: P0

**Steps**:

1. On a list item in insert mode, press `<Tab>` → indents; press `<S-Tab>` → outdents. Verify numbered lists renumber correctly.


**Expected Result**: Identical to before. Foreign `<Tab>`/`<S-Tab>` counters unchanged.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 3. `<CR>` on non-list line — real Enter behavior restored

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Non-list paragraph line, cursor mid-line, press `<CR>`.
2. If using cmp/blink: open a completion menu on a non-list line and confirm an entry with `<CR>`.

hello
world
**Expected Result**: Line splits at cursor like plain Vim; completion confirm works (previously the plugin hand-split and bypassed your `<CR>` mapping). Foreign counter increments (or cmp confirm fires).

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 4. `<CR>` autoindent / comment continuation on non-list lines

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Indented non-list line (e.g. `    some text`), cursor at end, press `<CR>`.
2. Type an abbreviation you have defined (if any), then `<CR>`.
    some text
    hello

**Expected Result**: New line keeps indent (`'autoindent'` honored); abbreviations expand. Previously cursor was forced to column 0 and abbreviations were skipped.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 5. `<Tab>` / `<S-Tab>` on non-list lines reach your mappings

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Non-list line, insert mode, press `<Tab>`, then `<S-Tab>`.
2. If you use a snippet/completion `<Tab>` mapping: verify it triggers (e.g. snippet jump, cmp select).

**Expected Result**: Foreign counters increment / your snippet-completion `<Tab>` works. Without foreign mapping: a literal tab / dedent as native.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 6. Code block — `<BS>` pair deletion NOW WORKS (Phase-1 case 11 fixed)

**Category**: Happy Path | **Priority**: P0

**Steps**:

1. Inside a fenced block:
   ````
   ```lua
   x = (|)
   ```
   ````
   (parens typed with autopairs)
2. Press `<BS>`.

```lua
x =
```
**Expected Result**: **Both** parens deleted — pairs honored inside fences now.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 7. Code block — `<CR>` and `<Tab>` honor foreign mappings

**Category**: Happy Path | **Priority**: P1

**Steps**:

1. Inside the same fenced block, press `<CR>` mid-line, then `<Tab>`.
2. With mini.pairs: type `{` at end of a line in the block, press `<CR>` — pairs' smart brace-expand should fire if you use that feature.

**Expected Result**: Foreign counters increment; native behavior when no foreign map. No list logic fires inside the fence.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 8. Code block — `o` / `O` still work in normal mode

**Category**: Regression | **Priority**: P1

**Steps**:

1. Normal mode on a line inside the fenced block, press `o`, escape, press `O`.

```

line


```
**Expected Result**: Plain new line below/above, insert mode entered — exactly as before Phase 2. (If you have a custom normal-mode `o` mapping, it now fires inside fences.)

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 9. `o` / `O` on list lines unchanged

**Category**: Regression | **Priority**: P0

**Steps**:

1. Normal mode on `- item` (outside any fence), press `o` → new list item below. Escape, press `O` → item above.
-
- item
-
**Expected Result**: List continuation exactly as before.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 10. `<A-CR>` KNOWN LIMITATION — non-list hand-roll remains

**Category**: Edge Case | **Priority**: P2

**Steps**:

1. Non-list line, insert mode, press `<A-CR>` (list "continue content" key).

hello world

**Expected Result**: Plain line split with cursor at column 0 (old hand-rolled behavior — deliberately unchanged; decision deferred to Phase 4). In a code block it defers like other keys.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 11. Erroring foreign `<CR>` mapping — graceful degradation

**Category**: Error Handling | **Priority**: P1

**Steps**:

1. `:lua vim.keymap.set("i", "<CR>", function() error("boom") end)` (global).
2. Non-list line, insert mode, press `<CR>`.
3. Clean up: `:lua vim.keymap.del("i", "<CR>")`.

hello world

**Expected Result**: `markdown-plus:`-prefixed error notification, key degrades to plain newline, no stuck insert mode.

**Result**: [ ] PASS [ ] FAIL

**Notes**:

>

---

### 11b. Capturing completion plugins — no freeze (blink.cmp / copilot.lua)

**Category**: Error Handling | **Priority**: P0

Plugins like blink.cmp and copilot.lua *replace* our buffer-local `<Tab>`/`<S-Tab>`
and capture the mapping they displaced (our `<Plug>(MarkdownPlus…)`) as **their**
fallback. Without a loop breaker this ping-pongs forever and hard-freezes Neovim.

**Steps**:

1. Use your real config, with blink.cmp and/or copilot.lua enabled.
2. Open a markdown file, put the cursor on a non-list line (inside a fenced code block is fine).
3. Insert mode, press `<Tab>` several times, then `<S-Tab>` several times.
4. `:imap <Tab>` — expect the completion plugin's mapping, not ours.

**Expected Result**: Every press resolves immediately. No freeze, no hang, no
runaway CPU. When the completion plugin has nothing to do, the key degrades to its
raw/native behavior.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 12. Non-markdown buffers unaffected

**Category**: Regression | **Priority**: P0

**Steps**:

1. `.lua`/`.txt` file: `<CR>`, `<Tab>`, `<S-Tab>`, `o`, `O` behave as your normal config; `:imap <CR>` shows no MarkdownPlus entry.

**Expected Result**: Identical to normal editing.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 13. Typing flow — no lag, no key reordering

**Category**: Performance | **Priority**: P2

**Steps**:

1. Type a few fast paragraphs with mixed `<CR>`/`<Tab>`/`<BS>` in and out of lists and fences.

**Expected Result**: No lag, no characters appearing out of order, no stray keys.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

### 14. Health + startup clean

**Category**: Regression | **Priority**: P2

**Steps**:

1. Fresh `nvim /tmp/376-test.md`, `:checkhealth markdown-plus`, `:messages`.

**Expected Result**: Health OK, no new warnings/errors.

**Result**: [x] PASS [ ] FAIL

**Notes**:

>

---

## Summary

**Overall Result**: [x] PASS [ ] FAIL
**Tested By**:
**General Notes**:

> (especially: does `<CR>` with your completion plugin feel right on non-list lines, and any surprises inside code fences?)
