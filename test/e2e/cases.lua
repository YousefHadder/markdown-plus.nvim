-- End-to-end scenarios for the #387 empty-checkbox fix, mirroring TESTING.md.
--
-- Each case is driven through the real buffer-local keymaps with real keypresses, so a pass
-- means the whole chain works: filetype detection, keymap registration, handler dispatch and
-- the parser fix underneath. Expected values are exact whole lines — the bug this guards
-- against produced a *duplicated bracket*, which a substring check would have missed.
--
---@class markdown-plus.e2e.Case
---@field name string Human-readable scenario name
---@field priority string "P0" | "P1" | "P2"
---@field lines string[] Buffer contents before the keys are pressed
---@field cursor? number[] {row, col} 1-indexed row, 0-indexed col. Defaults to {1, 0}
---@field keys string Key sequence, in Neovim notation, fed through real mappings
---@field expected string[] Exact buffer contents afterwards

-- localleader is "," in test/e2e/init.lua, so the checkbox toggle default is ",mx".
local TOGGLE = ",mx"

return {
  -- ---------------------------------------------------------------- P0: corruption path
  {
    name = "toggle empty unchecked task (main wrote '- [ ] [ ]')",
    priority = "P0",
    lines = { "- [ ]" },
    keys = TOGGLE,
    expected = { "- [x] " },
  },
  {
    name = "toggle empty checked task",
    priority = "P0",
    lines = { "- [x]" },
    keys = TOGGLE,
    expected = { "- [ ] " },
  },
  {
    name = "toggle empty checked task, capital X",
    priority = "P0",
    lines = { "- [X]" },
    keys = TOGGLE,
    expected = { "- [ ] " },
  },
  {
    name = "toggle round-trip does not accumulate content",
    priority = "P0",
    lines = { "- [ ]" },
    keys = TOGGLE .. TOGGLE,
    expected = { "- [ ] " },
  },
  {
    name = "toggle from insert mode via <C-t>",
    priority = "P0",
    lines = { "- [ ]" },
    cursor = { 1, 3 },
    keys = "i<C-t><Esc>",
    expected = { "- [x] " },
  },
  {
    name = "toggle a visual range mixing empty and content tasks",
    priority = "P0",
    lines = { "- [ ]", "- [ ] real task", "- [x]", "- [x] done task" },
    keys = "ggVG" .. TOGGLE,
    expected = { "- [x] ", "- [x] real task", "- [ ] ", "- [ ] done task" },
  },

  -- ---------------------------------------------------------------- P0: Enter behavior
  {
    name = "Enter on an empty task breaks out of the list",
    priority = "P0",
    lines = { "- [ ]" },
    keys = "A<CR><Esc>",
    expected = { "" },
  },
  -- The continued item carries a trailing space: the list prefix builder always emits the
  -- marker-to-content pad. Pre-existing behavior, and the reason an untouched empty task
  -- becomes "- [ ]" once trailing whitespace is trimmed on save — the cycle behind #387.
  {
    name = "Enter on a task with content continues the list",
    priority = "P0",
    lines = { "- [ ] real task" },
    keys = "A<CR><Esc>",
    expected = { "- [ ] real task", "- [ ] " },
  },
  {
    name = "Enter on a checked task continues with a fresh unchecked box",
    priority = "P0",
    lines = { "- [x] done task" },
    keys = "A<CR><Esc>",
    expected = { "- [x] done task", "- [ ] " },
  },

  -- ---------------------------------------------------------------- P0: must not over-match
  -- The anchored patterns require the bracket to end the line, so "- [ ]x" stays a plain
  -- list item whose content happens to start with "[ ]". Continuing it therefore yields a
  -- bare marker, not a checkbox — this is the assertion that catches an over-broad pattern.
  {
    name = "'- [ ]x' is not an empty task (continues as a plain item)",
    priority = "P0",
    lines = { "- [ ]x" },
    keys = "A<CR><Esc>",
    expected = { "- [ ]x", "- " },
  },
  {
    name = "'- [not a checkbox' is not a checkbox (Enter continues as a plain item)",
    priority = "P0",
    lines = { "- [not a checkbox" },
    keys = "A<CR><Esc>",
    expected = { "- [not a checkbox", "- " },
  },
  {
    name = "trailing-space form '- [ ] ' behaves identically to '- [ ]'",
    priority = "P0",
    lines = { "- [ ] " },
    keys = TOGGLE,
    expected = { "- [x] " },
  },

  -- ---------------------------------------------------------------- P1: marker families
  {
    name = "toggle empty task, '*' marker",
    priority = "P1",
    lines = { "* [ ]" },
    keys = TOGGLE,
    expected = { "* [x] " },
  },
  {
    name = "toggle empty task, '+' marker",
    priority = "P1",
    lines = { "+ [ ]" },
    keys = TOGGLE,
    expected = { "+ [x] " },
  },
  {
    name = "toggle empty ordered task",
    priority = "P1",
    lines = { "1. [ ]" },
    keys = TOGGLE,
    expected = { "1. [x] " },
  },
  {
    name = "toggle empty parenthesized ordered task",
    priority = "P1",
    lines = { "1) [ ]" },
    keys = TOGGLE,
    expected = { "1) [x] " },
  },
  {
    name = "toggle empty lowercase lettered task",
    priority = "P1",
    lines = { "a. [ ]" },
    keys = TOGGLE,
    expected = { "a. [x] " },
  },
  {
    name = "toggle empty uppercase lettered task",
    priority = "P1",
    lines = { "A. [x]" },
    keys = TOGGLE,
    expected = { "A. [ ] " },
  },
  {
    name = "Enter breaks out of an empty ordered task",
    priority = "P1",
    lines = { "1. [ ]" },
    keys = "A<CR><Esc>",
    expected = { "" },
  },

  -- ---------------------------------------------------------------- P1: states + indent
  {
    name = "custom state '-' counts as unchecked",
    priority = "P1",
    lines = { "- [-]" },
    keys = TOGGLE,
    expected = { "- [x] " },
  },
  {
    name = "custom state '~' counts as unchecked",
    priority = "P1",
    lines = { "- [~]" },
    keys = TOGGLE,
    expected = { "- [x] " },
  },
  {
    name = "toggle a nested empty task keeps its indentation",
    priority = "P1",
    lines = { "- parent", "  - [ ]" },
    cursor = { 2, 0 },
    keys = TOGGLE,
    expected = { "- parent", "  - [x] " },
  },
  {
    name = "Enter on a nested empty task keeps the indentation",
    priority = "P1",
    lines = { "- parent", "  - [ ]" },
    cursor = { 2, 0 },
    keys = "A<CR><Esc>",
    expected = { "- parent", "  " },
  },

  -- ---------------------------------------------------------------- P1: neighbouring features
  {
    name = "Tab indents an empty task without disturbing the box",
    priority = "P1",
    lines = { "- first", "- [ ]" },
    cursor = { 2, 0 },
    keys = "A<Tab><Esc>",
    expected = { "- first", "  - [ ] " },
  },
  -- Renumbering is <localleader>mr. The point of this case is that an empty task counts as
  -- a member of the list: the new patterns are deliberately not flagged as "empty", so
  -- group scanning must not treat this line as a break in the list.
  {
    name = "an empty task stays a list member for renumbering",
    priority = "P1",
    lines = { "1. first", "1. [ ]", "1. third" },
    keys = ",mr",
    expected = { "1. first", "2. [ ] ", "3. third" },
  },

  -- ---------------------------------------------------------------- P2: documented reach
  {
    name = "'- [a]' reads as checkbox state 'a' (pre-existing, deliberate)",
    priority = "P2",
    lines = { "- [a]" },
    keys = TOGGLE,
    expected = { "- [x] " },
  },
}
