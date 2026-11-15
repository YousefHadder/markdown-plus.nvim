-- Parent/child checkbox synchronization for markdown-plus.nvim
-- Pure planning: reads buffer lines, returns the checkbox states to write. Never edits the buffer.
local parser = require("markdown-plus.list.parser")
local code_block_parser = require("markdown-plus.code_block.parser")
local utils = require("markdown-plus.utils")
local M = {}

local html_awareness = true

---Set HTML block awareness state, as for list group scanning.
---@param enabled boolean
---@return nil
function M.set_html_awareness(enabled)
  html_awareness = enabled ~= false
end

---@class markdown-plus.list.CheckboxNode
---@field row number 1-indexed line number
---@field indent number Display width of the indentation before the marker
---@field state string|nil Checkbox state, or nil for a list item without a checkbox
---@field parent markdown-plus.list.CheckboxNode|nil Enclosing list item
---@field children markdown-plus.list.CheckboxNode[] Directly nested list items

---@class markdown-plus.list.CheckboxChange
---@field row number 1-indexed line number of a toggled list item
---@field added? boolean True when the toggle added the checkbox rather than changing its state
---@field structural? boolean True when the item moved in the tree (indented, outdented, inserted,
---or it gained or lost children) instead of changing state: it is recomputed from its children
---rather than pushing its state down. A row that is not a list item stands for the nearest list
---item above it.

---@class markdown-plus.list.CheckboxUpdate
---@field row number 1-indexed line number to rewrite
---@field state string New checkbox state

---Default checkbox states: unchecked, then checked
M.DEFAULT_STATES = { " ", "x" }

---Check whether a checkbox state counts as checked
---@param state string|nil
---@return boolean
function M.is_checked(state)
  return state == "x" or state == "X"
end

---Normalize a checkbox state so `X` compares equal to `x`
---@param state string|nil
---@return string|nil
local function normalize(state)
  return M.is_checked(state) and "x" or state
end

---Check whether sync may read and rewrite a checkbox state.
---Only configured states are managed; custom states such as `[-]` or `[?]` belong to the user.
---@param state string|nil
---@param states? string[] Configured checkbox states (default: `{ " ", "x" }`)
---@return boolean
function M.is_managed(state, states)
  state = normalize(state)
  return state ~= nil and vim.tbl_contains(states or M.DEFAULT_STATES, state)
end

---Get the state after `state` in `states`, wrapping around to the first.
---Unknown states start over at the first state.
---@param state string|nil
---@param states? string[] Configured checkbox states (default: `{ " ", "x" }`)
---@return string
function M.next_state(state, states)
  states = states or M.DEFAULT_STATES
  state = normalize(state)
  for i, candidate in ipairs(states) do
    if candidate == state then
      return states[i % #states + 1]
    end
  end
  return states[1]
end

---Pop stack entries that cannot contain a line at the given indentation
---@param stack markdown-plus.list.CheckboxNode[]
---@param width number
---@return nil
local function close_items(stack, width)
  while #stack > 0 and stack[#stack].indent >= width do
    table.remove(stack)
  end
end

---Build the list item tree for a buffer.
---Fenced code blocks and HTML blocks (when awareness is enabled) are skipped.
---Any other non-list line closes the items it is not indented under.
---@param lines string[] All buffer lines
---@return table<number, markdown-plus.list.CheckboxNode> nodes List items keyed by row
function M.build_tree(lines)
  local nodes = {}
  local stack = {}
  local fence = nil
  local html_block_lines = html_awareness and utils.get_html_block_lines(lines) or {}

  for row, line in ipairs(lines) do
    if html_block_lines[row] then
      -- Like group_scanner, ignore the whole HTML block without changing list ancestry.
      goto continue
    end
    if fence then
      if code_block_parser.parse_closing_fence(line, fence) then
        fence = nil
      end
    else
      local opening = code_block_parser.parse_opening_fence(line)
      local list_info = not opening and parser.parse_list_line(line) or nil
      if list_info then
        local width = vim.fn.strdisplaywidth(list_info.indent)
        close_items(stack, width)
        local node = {
          row = row,
          indent = width,
          state = list_info.checkbox,
          parent = stack[#stack],
          children = {},
        }
        if node.parent then
          table.insert(node.parent.children, node)
        end
        nodes[row] = node
        table.insert(stack, node)
      elseif line:match("%S") then
        close_items(stack, vim.fn.strdisplaywidth(line:match("^%s*")))
        fence = opening
      end
    end
    ::continue::
  end

  return nodes
end

---Collect the nearest checkbox items below a node, looking through items without a checkbox
---@param node markdown-plus.list.CheckboxNode
---@param result? markdown-plus.list.CheckboxNode[]
---@return markdown-plus.list.CheckboxNode[]
local function checkbox_children(node, result)
  result = result or {}
  for _, child in ipairs(node.children) do
    if child.state then
      table.insert(result, child)
    else
      checkbox_children(child, result)
    end
  end
  return result
end

---Find the list item on a row, or the nearest one above it
---@param nodes table<number, markdown-plus.list.CheckboxNode>
---@param row number
---@return markdown-plus.list.CheckboxNode|nil
local function node_at_or_above(nodes, row)
  for candidate = row, 1, -1 do
    if nodes[candidate] then
      return nodes[candidate]
    end
  end
  return nil
end

---Plan the checkbox updates that keep parents and children consistent after toggles.
---Items toggled to the first or last state push it down to their descendants (except descendants
---that were toggled themselves), structural changes mark their item for recomputation, then every
---marked item and every ancestor is recomputed from its children: last state when all of them are
---done, first state when none has started, and the first in-between state (or the first state when
---there is none) otherwise.
---@param lines string[] All buffer lines, after the toggles were applied
---@param changes markdown-plus.list.CheckboxChange[] Toggled or moved list items
---@param states? string[] Configured checkbox states (default: `{ " ", "x" }`)
---@return markdown-plus.list.CheckboxUpdate[] updates Sorted by row
function M.plan(lines, changes, states)
  states = states or M.DEFAULT_STATES
  local first, last = states[1], states[#states]
  local partial = #states > 2 and states[2] or first
  local nodes = M.build_tree(lines)
  local toggled = {}
  for _, change in ipairs(changes) do
    if not change.structural then
      toggled[change.row] = true
    end
  end

  local updates = {}

  ---@param node markdown-plus.list.CheckboxNode
  ---@param state string
  ---@return nil
  local function set_state(node, state)
    if normalize(node.state) ~= state then
      node.state = state
      updates[node.row] = state
    end
  end

  ---@param node markdown-plus.list.CheckboxNode
  ---@param state string
  ---@return nil
  local function push_down(node, state)
    for _, child in ipairs(node.children) do
      if not toggled[child.row] and (child.state == nil or M.is_managed(child.state, states)) then
        if child.state then
          set_state(child, state)
        end
        push_down(child, state)
      end
    end
  end

  local recompute = {}
  ---@param node markdown-plus.list.CheckboxNode|nil
  ---@return nil
  local function mark(node)
    while node and not recompute[node.row] do
      recompute[node.row] = node
      node = node.parent
    end
  end

  for _, change in ipairs(changes) do
    if change.structural then
      mark(node_at_or_above(nodes, change.row))
    else
      local node = nodes[change.row]
      if node then
        -- Starting a parent does not mean every child has started, so in-between states stay put
        local state = normalize(node.state)
        if not change.added and (state == first or state == last) then
          push_down(node, state)
        end
        mark(node.parent)
      end
    end
  end

  -- Children always sit below their parents, so walking up the buffer settles them first
  local rows = vim.tbl_keys(recompute)
  table.sort(rows, function(a, b)
    return a > b
  end)
  for _, row in ipairs(rows) do
    local node = recompute[row]
    if M.is_managed(node.state, states) then
      local total, done, open = 0, 0, 0
      for _, child in ipairs(checkbox_children(node)) do
        if M.is_managed(child.state, states) then
          total = total + 1
          local state = normalize(child.state)
          if state == last then
            done = done + 1
          elseif state == first then
            open = open + 1
          end
        end
      end
      if total > 0 then
        set_state(node, done == total and last or open == total and first or partial)
      end
    end
  end

  local result = {}
  for row, state in pairs(updates) do
    table.insert(result, { row = row, state = state })
  end
  table.sort(result, function(a, b)
    return a.row < b.row
  end)
  return result
end

---Describe the parts of a line that sync reads: its indentation and, for a list item, its checkbox.
---Lines with equal keys put their item at the same place in the tree with the same state.
---@param line string
---@return string key `""` for a blank line, `"<width>"` for other text, `"<width>-"` for a list
---item without a checkbox and `"<width>[<state>]"` for a task
function M.line_key(line)
  local list_info = parser.parse_list_line(line)
  if not list_info then
    local indent = line:match("^%s*")
    return #indent == #line and "" or tostring(vim.fn.strdisplaywidth(indent))
  end
  local width = vim.fn.strdisplaywidth(list_info.indent)
  return list_info.checkbox and string.format("%d[%s]", width, list_info.checkbox) or width .. "-"
end

---@param key string A `line_key` result
---@return string|nil width, string|nil checkbox `"-"` or `"[<state>]"` for list items, nil otherwise
local function split_key(key)
  local width, rest = key:match("^(%d+)(.*)$")
  return width, rest ~= "" and rest or nil
end

---Describe how an edit changed a line, given its `line_key` before and after.
---@param old_key string
---@param new_key string
---@return markdown-plus.list.CheckboxChange|nil change Without `row`; nil when sync has nothing to do
function M.classify_edit(old_key, new_key)
  if old_key == new_key then
    return nil
  end
  local old_width, old_box = split_key(old_key)
  local new_width, new_box = split_key(new_key)
  if old_box and new_box and old_width == new_width then
    return { added = old_box == "-" }
  end
  return { structural = true }
end

return M
