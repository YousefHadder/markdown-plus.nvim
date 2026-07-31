-- List pattern data for markdown-plus.nvim
-- Static pattern/configuration data shared by the treesitter and regex parsing paths.
local ts = require("markdown-plus.treesitter")
local M = {}

-- Constants
M.DELIMITER_DOT = "."
M.DELIMITER_PAREN = ")"

local DELIMITER_DOT = M.DELIMITER_DOT
local DELIMITER_PAREN = M.DELIMITER_PAREN

---Map treesitter marker nodes to list type names
M.TS_MARKER_TYPES = {
  [ts.nodes.LIST_MARKER_MINUS] = { type = "unordered", marker = "-", delimiter = "" },
  [ts.nodes.LIST_MARKER_PLUS] = { type = "unordered", marker = "+", delimiter = "" },
  [ts.nodes.LIST_MARKER_STAR] = { type = "unordered", marker = "*", delimiter = "" },
  [ts.nodes.LIST_MARKER_DOT] = { type = "ordered", delimiter = DELIMITER_DOT },
  [ts.nodes.LIST_MARKER_PARENTHESIS] = { type = "ordered_paren", delimiter = DELIMITER_PAREN },
}

-- Map checkbox nodes to checkbox state
M.TS_CHECKBOX_TYPES = {
  [ts.nodes.TASK_LIST_MARKER_UNCHECKED] = " ",
  [ts.nodes.TASK_LIST_MARKER_CHECKED] = "x",
}

---List patterns for detection
---@class markdown-plus.list.Patterns
---@field unordered string Pattern for unordered lists (-, +, *)
---@field ordered string Pattern for ordered lists (1., 2., etc.)
---@field checkbox string Pattern for checkbox lists (- [ ], - [x], etc.)
---@field ordered_checkbox string Pattern for ordered checkbox lists (1. [ ], etc.)
---@field letter_lower string Pattern for lowercase letter lists (a., b., c.)
---@field letter_upper string Pattern for uppercase letter lists (A., B., C.)
---@field letter_lower_checkbox string Pattern for lowercase letter checkbox lists (a. [ ])
---@field letter_upper_checkbox string Pattern for uppercase letter checkbox lists (A. [ ])
---@field ordered_paren string Pattern for parenthesized ordered lists (1), 2), etc.)
---@field letter_lower_paren string Pattern for parenthesized lowercase letter lists (a), b), c.)
---@field letter_upper_paren string Pattern for parenthesized uppercase letter lists (A), B), C.)
---@field ordered_paren_checkbox string Pattern for parenthesized ordered checkbox lists (1) [ ])
---@field letter_lower_paren_checkbox string Pattern for parenthesized lowercase letter checkbox lists (a) [ ])
---@field letter_upper_paren_checkbox string Pattern for parenthesized uppercase letter checkbox lists (A) [ ])
---@field checkbox_empty string Pattern for unordered checkbox items with nothing after `]` (- [ ])
---@field ordered_checkbox_empty string Pattern for ordered checkbox items with nothing after `]` (1. [ ])
---@field letter_lower_checkbox_empty string Pattern for lowercase letter checkbox items at EOL (a. [ ])
---@field letter_upper_checkbox_empty string Pattern for uppercase letter checkbox items at EOL (A. [ ])
---@field ordered_paren_checkbox_empty string Pattern for parenthesized ordered checkbox items at EOL (1) [ ])
---@field letter_lower_paren_checkbox_empty string Pattern for parenthesized lowercase letter checkboxes at EOL (a) [ ])
---@field letter_upper_paren_checkbox_empty string Pattern for parenthesized uppercase letter checkboxes at EOL (A) [ ])
---@field unordered_empty string Pattern for empty unordered lists at EOL (-, +, *)
---@field ordered_empty string Pattern for empty ordered lists at EOL (1., 2., etc.)
---@field letter_lower_empty string Pattern for empty lowercase letter lists at EOL (a., b., c.)
---@field letter_upper_empty string Pattern for empty uppercase letter lists at EOL (A., B., C.)
---@field ordered_paren_empty string Pattern for empty parenthesized ordered lists at EOL (1), 2), etc.)
---@field letter_lower_paren_empty string Pattern for empty parenthesized lowercase letter lists at EOL (a), b), c.)
---@field letter_upper_paren_empty string Pattern for empty parenthesized uppercase letter lists at EOL (A), B), C.)

---@type markdown-plus.list.Patterns
M.patterns = {
  unordered = "^(%s*)([%-%+%*])%s+",
  ordered = "^(%s*)(%d+)%.%s+",
  checkbox = "^(%s*)([%-%+%*])%s+%[(.?)%]%s+",
  ordered_checkbox = "^(%s*)(%d+)%.%s+%[(.?)%]%s+",
  letter_lower = "^(%s*)([a-z])%.%s+",
  letter_upper = "^(%s*)([A-Z])%.%s+",
  letter_lower_checkbox = "^(%s*)([a-z])%.%s+%[(.?)%]%s+",
  letter_upper_checkbox = "^(%s*)([A-Z])%.%s+%[(.?)%]%s+",
  ordered_paren = "^(%s*)(%d+)%)%s+",
  letter_lower_paren = "^(%s*)([a-z])%)%s+",
  letter_upper_paren = "^(%s*)([A-Z])%)%s+",
  ordered_paren_checkbox = "^(%s*)(%d+)%)%s+%[(.?)%]%s+",
  letter_lower_paren_checkbox = "^(%s*)([a-z])%)%s+%[(.?)%]%s+",
  letter_upper_paren_checkbox = "^(%s*)([A-Z])%)%s+%[(.?)%]%s+",
  -- Empty checkbox patterns: closing bracket is the last thing on the line.
  -- The with-content variants above require whitespace after `]`, so an untouched empty task
  -- (the normal state once trailing whitespace is trimmed) would otherwise parse as a plain
  -- list item whose content is "[ ]" (issue #387). Anchored with `$` so a checkbox prefix
  -- followed by real content never matches here.
  -- The state capture is `.?`, matching the with-content variants above: any single character
  -- counts as a checkbox state, which keeps custom states ("-", "~", …) working. The knock-on
  -- effect is that a CommonMark shortcut reference link alone on the line ("- [a]") reads as
  -- checkbox state "a" — deliberate, not an oversight: "- [a] text" already parses that way,
  -- so treating the EOL form differently would be the inconsistency.
  checkbox_empty = "^(%s*)([%-%+%*])%s+%[(.?)%]$",
  ordered_checkbox_empty = "^(%s*)(%d+)%.%s+%[(.?)%]$",
  letter_lower_checkbox_empty = "^(%s*)([a-z])%.%s+%[(.?)%]$",
  letter_upper_checkbox_empty = "^(%s*)([A-Z])%.%s+%[(.?)%]$",
  ordered_paren_checkbox_empty = "^(%s*)(%d+)%)%s+%[(.?)%]$",
  letter_lower_paren_checkbox_empty = "^(%s*)([a-z])%)%s+%[(.?)%]$",
  letter_upper_paren_checkbox_empty = "^(%s*)([A-Z])%)%s+%[(.?)%]$",
  -- Empty item patterns (marker at end of line, no trailing space required)
  -- These handle the case where trim_trailing_whitespace removes the space
  unordered_empty = "^(%s*)([%-%+%*])$",
  ordered_empty = "^(%s*)(%d+)%.$",
  letter_lower_empty = "^(%s*)([a-z])%.$",
  letter_upper_empty = "^(%s*)([A-Z])%.$",
  ordered_paren_empty = "^(%s*)(%d+)%)$",
  letter_lower_paren_empty = "^(%s*)([a-z])%)$",
  letter_upper_paren_empty = "^(%s*)([A-Z])%)$",
}

-- Pattern configuration: defines order and metadata for pattern matching
M.PATTERN_CONFIG = {
  { pattern = "ordered_checkbox", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_lower_checkbox", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_upper_checkbox", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "checkbox", type = "unordered", delimiter = "", has_checkbox = true },
  { pattern = "ordered_paren_checkbox", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = true },
  {
    pattern = "letter_lower_paren_checkbox",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  {
    pattern = "letter_upper_paren_checkbox",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  -- Empty checkbox variants (nothing after `]`). They must precede the plain marker patterns
  -- below, which would otherwise swallow "- [ ]" as an unordered item with content "[ ]".
  -- Unlike the bare empty-marker patterns at the end of this list these are NOT flagged
  -- `is_empty`, so callers passing `skip_empty_patterns` (group scanning) still see these lines
  -- as list items — exactly as they already see the trailing-space form "- [ ] ".
  { pattern = "ordered_checkbox_empty", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_lower_checkbox_empty", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "letter_upper_checkbox_empty", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = true },
  { pattern = "checkbox_empty", type = "unordered", delimiter = "", has_checkbox = true },
  {
    pattern = "ordered_paren_checkbox_empty",
    type = "ordered_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  {
    pattern = "letter_lower_paren_checkbox_empty",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  {
    pattern = "letter_upper_paren_checkbox_empty",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = true,
  },
  { pattern = "ordered", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_lower", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_upper", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "ordered_paren", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_lower_paren", type = "letter_lower_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_upper_paren", type = "letter_upper_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "unordered", type = "unordered", delimiter = "", has_checkbox = false },
  -- Empty item patterns (marker at EOL without trailing space)
  -- These are checked last to prefer matching with content when possible
  -- is_empty allows callers to skip these when scanning for group membership
  {
    pattern = "ordered_empty",
    type = "ordered",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_lower_empty",
    type = "letter_lower",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_upper_empty",
    type = "letter_upper",
    delimiter = DELIMITER_DOT,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "ordered_paren_empty",
    type = "ordered_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_lower_paren_empty",
    type = "letter_lower_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  {
    pattern = "letter_upper_paren_empty",
    type = "letter_upper_paren",
    delimiter = DELIMITER_PAREN,
    has_checkbox = false,
    is_empty = true,
  },
  { pattern = "unordered_empty", type = "unordered", delimiter = "", has_checkbox = false, is_empty = true },
}

return M
