-- Public list-context query for markdown-plus.nvim
--
-- markdown-plus installs buffer-local defaults for keys other plugins commonly own. The
-- handlers yield back through `keymap_fallback` when they have nothing to do, which covers
-- the common case automatically. This module is the other direction: it lets a user or plugin
-- author own the key themselves and ask us whether *we* would have acted, so they can compose
-- their own mapping without guessing at our internals.
--
-- The predicate is exactly the one the matching handler uses — including the
-- `skip_in_codeblock` wrapper every list keymap is registered through — so
-- `in_list_context(kind) == false` guarantees the corresponding handler would defer.
local parser = require("markdown-plus.list.parser")
local handler_utils = require("markdown-plus.list.handler_utils")
local shared = require("markdown-plus.list.shared")
local utils = require("markdown-plus.utils")

local M = {}

---Which handler's notion of "list context" to query.
---@alias markdown-plus.ListContextKind
---| "enter" # `<CR>`: on a list item line *or* a wrapped continuation line
---| "backspace" # `<BS>`: at the start of list content, where the marker is removed
---| "indent" # `<Tab>`/`<S-Tab>`: on a list item line

---Whether the cursor sits on a line that carries a list marker
---@return boolean
local function on_list_item_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  return parser.parse_list_line(utils.get_current_line(), row) ~= nil
end

---Whether `<BS>` would remove the list marker.
---
---Narrower than "on a list item line" on purpose: `handle_backspace` only acts in the marker
---zone and defers *inside* list content, so a recipe keyed on the line alone would route
---mid-content backspaces into a handler that immediately hands them back — and a pairs plugin
---sitting behind our own mapping would never fire.
---@return boolean
local function would_remove_marker()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
  local current_line = utils.get_current_line()
  local list_info = parser.parse_list_line(current_line, row)
  if not list_info then
    return false
  end

  -- Mirrors the guard in `list/normal_handler.lua`'s `handle_backspace`.
  local marker_end_col = shared.get_content_start_col(list_info)
  return col <= marker_end_col and col > #list_info.indent
end

---Whether `<CR>` would continue a list: marker line, or a continuation line beneath one
---@return boolean
local function in_enter_context()
  if on_list_item_line() then
    return true
  end
  local cursor = utils.get_cursor()
  local row = cursor[1]
  return handler_utils.find_parent_list_item(row, utils.get_current_line()) ~= nil
end

---Predicate per kind. Keeping them in a table makes the accepted set the single source of
---truth for both dispatch and the error message.
local PREDICATES = {
  enter = in_enter_context,
  backspace = would_remove_marker,
  indent = on_list_item_line,
}

---Check whether the cursor is in list context for a given handler kind.
---
---Public API: stable across minor versions. Read-only and cheap — it parses the current line
---(plus a bounded look-back for `"enter"`) and never touches the buffer, so it is safe to call
---from an expression mapping.
---
---Every kind is `false` inside a fenced code block, whatever the line looks like: the handlers
---are wrapped in `skip_in_codeblock` and defer there unconditionally, so a `- item` in a
---```markdown fence is not a context we act in.
---
---Each kind answers "would the handler act?", not "would the buffer change?". `"indent"` is
---true anywhere on a list item line, including for `<S-Tab>` on an item already at root
---indentation, where the handler consumes the key without outdenting further. Route that key
---elsewhere if you need it to fall through in that position.
---
---```lua
---vim.keymap.set("i", "<BS>", function()
---  if require("markdown-plus").in_list_context("backspace") then
---    return "<Plug>(MarkdownPlusListBackspace)"
---  end
---  return require("mini.pairs").bs()
---end, { expr = true, buffer = true })
---```
---@param kind? markdown-plus.ListContextKind Handler context to query; defaults to `"enter"`
---@return boolean in_context `true` when the matching handler would act on the current cursor
function M.in_list_context(kind)
  local predicate = PREDICATES[kind or "enter"]
  if not predicate then
    vim.notify(
      string.format(
        'markdown-plus: in_list_context() got unknown kind %q (expected "enter", "backspace" or "indent")',
        tostring(kind)
      ),
      vim.log.levels.ERROR
    )
    return false
  end

  -- Deliberately silent on failure. This runs inside expression mappings on every keypress of
  -- `<BS>`/`<CR>`/`<Tab>`, where a `vim.notify` from a parse error (an unloaded treesitter
  -- parser mid-edit, say) would fire once per keystroke and bury the editor in messages.
  -- `false` is the safe answer: the caller falls through to its own non-markdown-plus branch,
  -- which is exactly what a user who cannot be told about the error wants.
  --
  -- The code-block check shares that pcall: every list keymap is registered through
  -- `handlers.skip_in_codeblock`, so a fenced line is never a context we act in — and the
  -- predicates below only look at the line's shape, which happily matches `- item` inside a
  -- ```markdown fence.
  local ok, result = pcall(function()
    if utils.is_in_code_block() then
      return false
    end
    return predicate()
  end)
  if not ok then
    return false
  end
  return result
end

return M
