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
---@field shiftwidth? number Indent width for this case. Defaults to 2.
---@field setup? fun() Runs after the buffer is seeded, before the keys are fed. Use it to
---       install a competing mapping so a wrongful handoff becomes observable. Errors fail
---       the case; global mappings are restored afterwards, including on setup failure.
---@field keys string Key sequence, in Neovim notation, fed through real mappings
---@field expected string[] Exact buffer contents afterwards

-- localleader is "," in test/e2e/init.lua, so the checkbox toggle default is ",mx".
local TOGGLE = ",mx"

---Stand in for a plugin that owns `<A-CR>` (Copilot maps it to accept a suggestion).
---markdown-plus installs its own default only when the key is unmapped, so this has to be
---a *global* mapping: a buffer-local one would suppress the plugin's mapping entirely and
---the case would prove nothing.
local function RIVAL_ALT_CR()
  vim.keymap.set("i", "<A-CR>", "RIVAL", { remap = false })
end

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

  -- ---------------------------------------------------------------- P1: table cell navigation
  -- Insert-mode table navigation is <A-h/j/k/l>. Landing position matters because the next
  -- thing the user does is type: an empty cell must put the cursor where content goes, not
  -- against the closing pipe. Asserting buffer contents after typing proves the landing spot
  -- without the harness needing to inspect the cursor.
  {
    name = "<A-j> lands at the start of an empty table cell",
    priority = "P1",
    lines = {
      "| H1 | H2 |",
      "| -- | -- |",
      "|    |    |",
    },
    cursor = { 1, 2 },
    keys = "i<A-j>x<Esc>",
    expected = {
      "| H1 | H2 |",
      "| -- | -- |",
      "| x   |    |",
    },
  },
  {
    name = "<A-l> lands at the start of the next empty table cell",
    priority = "P1",
    lines = {
      "| H1 | H2 |",
      "| -- | -- |",
      "|    |    |",
    },
    cursor = { 3, 2 },
    keys = "i<A-l>x<Esc>",
    expected = {
      "| H1 | H2 |",
      "| -- | -- |",
      "|    | x   |",
    },
  },

  -- ---------------------------------------------------------------- P1: nested list `o`
  -- Real users get shiftwidth=4 from the bundled markdown ftplugin. At that width the
  -- smart-outdent target indent collapsed to 0 and `o` on the last nested ordered child
  -- produced a *parent-level* item, abandoning the child sequence.
  {
    name = "'o' on the last nested ordered child continues the child list (sw=4)",
    priority = "P1",
    shiftwidth = 4,
    lines = { "1. Parent", "   1. Child one", "   2. Child two" },
    cursor = { 3, 6 },
    keys = "o",
    expected = { "1. Parent", "   1. Child one", "   2. Child two", "   3. " },
  },
  {
    name = "'o' on the last nested unordered child still continues the parent (sw=4)",
    priority = "P1",
    shiftwidth = 4,
    lines = { "1. Parent", "   - Child one", "   - Child two" },
    cursor = { 3, 5 },
    keys = "o",
    expected = { "1. Parent", "   - Child one", "   - Child two", "2. " },
  },

  -- ---------------------------------------------------------------- P1: repeated <A-CR>
  -- The second press lands on the continuation line the first one created. That line has no
  -- marker, so markdown-plus used to hand <A-CR> back to whatever else owned it.
  --
  -- In a bare Neovim that handoff is invisible: the raw key falls through to a newline and
  -- 'autoindent' reproduces the same indent the real handler would have used. It only bites
  -- once another plugin owns <A-CR> — so these cases install one, and a wrongful handoff
  -- shows up as the sentinel text in the buffer.
  {
    name = "repeated <A-CR> keeps adding continuation lines to the same item",
    priority = "P1",
    lines = { "- First line" },
    cursor = { 1, 11 },
    setup = RIVAL_ALT_CR,
    keys = "A<A-CR>second<A-CR>third<Esc>",
    expected = { "- First line", "  second", "  third" },
  },
  {
    name = "repeated <A-CR> holds ordered-item content alignment",
    priority = "P1",
    lines = { "1. First line" },
    cursor = { 1, 12 },
    setup = RIVAL_ALT_CR,
    keys = "A<A-CR>second<A-CR>third<Esc>",
    expected = { "1. First line", "   second", "   third" },
  },
  {
    name = "<A-CR> off a list still yields to another plugin's mapping",
    priority = "P1",
    lines = { "just a paragraph" },
    cursor = { 1, 4 },
    setup = RIVAL_ALT_CR,
    keys = "A<A-CR><Esc>",
    expected = { "just a paragraphRIVAL" },
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
