-- List renumbering module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local M = {}

local ORDERED_LIST_CANDIDATE_PATTERNS = {
  "^%s*%d+[%.%)]",
  "^%s*[A-Za-z][%.%)]",
}

---@type markdown-plus.InternalConfig
local config = {}

-- Recognized fence patterns — capture the fence character and its full run
-- e.g. "    ```python" captures indent="    ", fence_char="`", fence_run="```"
local CODE_FENCE_OPEN_PATTERN = "^(%s*)((`+)(.*))"
local CODE_FENCE_TILDE_OPEN_PATTERN = "^(%s*)((~+)(.*))"

---Set module configuration
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg)
  config = cfg or {}
end

---Check whether HTML block awareness is enabled (default: true)
---@return boolean
local function html_awareness_enabled()
  return not (config.features and config.features.html_block_awareness == false)
end

---Parse a line as a potential code fence opener or closer.
---Tracks fence character type and length per CommonMark §4.5:
---a closing fence must use the same character as the opener, be at least
---as long, and may only be followed by spaces/tabs.
---@param line string
---@param active_fence {char: string, len: number}|nil Currently open fence, if any
---@return {indent: string, char: string, len: number}|nil info Fence info, or nil if not a fence
local function parse_fence_line(line, active_fence)
  for _, pat in ipairs({ CODE_FENCE_OPEN_PATTERN, CODE_FENCE_TILDE_OPEN_PATTERN }) do
    local indent, _, fence_run, trailing = line:match(pat)
    if fence_run then
      local char = fence_run:sub(1, 1)
      local len = #fence_run
      if len >= 3 then
        if active_fence then
          -- Closing fence: must match char, length >= opener, and trailing
          -- text must be whitespace-only (CommonMark §4.5)
          if char == active_fence.char and len >= active_fence.len and trailing:match("^%s*$") then
            return { indent = indent, char = char, len = len }
          end
          -- Not a valid closer — treat as content inside the block
          return nil
        end
        -- Opening fence: trailing info string is allowed
        return { indent = indent, char = char, len = len }
      end
    end
  end
  return nil
end

---Build set of line numbers inside fenced code blocks using regex fence-toggle
---scanning. Tracks fence character/length per CommonMark to avoid mismatched
---closers. For indented fences (nested in list items), adjacent blank lines
---are absorbed into the set so they don't independently break list group
---continuity. Also marks non-indented code block regions so find_list_groups
---can clear active groups when encountering them.
---@param lines string[] All buffer lines
---@return table<number, boolean> code_lines Set of 1-indexed line numbers inside code blocks
---@return table<number, boolean> non_indented_regions Set of 1-indexed line numbers inside NON-indented code blocks
local function get_fenced_code_block_lines(lines)
  local code_lines = {}
  local non_indented_regions = {}
  local active_fence = nil
  local block_start = nil

  for i, line in ipairs(lines) do
    if not active_fence then
      local info = parse_fence_line(line, nil)
      if info then
        code_lines[i] = true
        active_fence = { char = info.char, len = info.len }
        block_start = i
        -- Only column-0 fences are unambiguous structural separators.
        -- Fences indented 1+ spaces adjacent to list items are treated as
        -- nested content (the list marker width determines nesting, not the
        -- CommonMark standalone 0-3 rule which doesn't apply inside lists).
        if #info.indent == 0 then
          non_indented_regions[i] = true
        end
      end
    else
      code_lines[i] = true
      -- Check if opening fence was non-indented — propagate to all lines in block
      if non_indented_regions[block_start] then
        non_indented_regions[i] = true
      end
      local info = parse_fence_line(line, active_fence)
      if info then
        -- Valid closer found
        active_fence = nil
        block_start = nil
      end
    end
  end

  -- Absorb adjacent blank lines for INDENTED fences only.
  -- Indented fences are nested content of a list item; blank lines between
  -- the list item and the fence should not break group continuity.
  -- Non-indented (column 0) fences genuinely separate lists, so their
  -- adjacent blank lines are NOT absorbed.
  local expanded = {}
  for k, v in pairs(code_lines) do
    expanded[k] = v
  end

  for i = 1, #lines do
    if code_lines[i] and not code_lines[i - 1] then
      -- Opening fence — absorb preceding blank lines if fence is indented
      if not non_indented_regions[i] then
        local j = i - 1
        while j >= 1 and lines[j]:match("^%s*$") do
          expanded[j] = true
          j = j - 1
        end
      end
    end
    if code_lines[i] and not code_lines[i + 1] then
      -- Closing fence — absorb following blank lines if fence is indented
      if not non_indented_regions[i] then
        local j = i + 1
        while j <= #lines and lines[j]:match("^%s*$") do
          expanded[j] = true
          j = j + 1
        end
      end
    end
  end

  return expanded, non_indented_regions
end

---Check if a line breaks list continuity
---@param line string
---@param line_num number|nil The line number (1-indexed). Optional, but must be provided together with `lines` for continuation line checks.
---@param lines string[]|nil All buffer lines. Optional, but must be provided together with `line_num` for continuation line checks.
---@return boolean
function M.is_list_breaking_line(line, line_num, lines)
  -- Empty lines terminate list groups
  if not line or line:match("^%s*$") then
    -- But check if it's a continuation line first
    if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
      return false
    end
    return true
  end

  -- Any non-list content breaks list continuity
  if parser.parse_list_line(line, line_num) then
    return false
  end

  -- Check if it's a continuation line
  if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
    return false
  end

  -- Any non-list content (headers, paragraphs, etc.) breaks list continuity
  return true
end

---Check whether groups can be merged without crossing structural separators.
---All lines between groups must be blank or deeper-indented than parent indent.
---@param lines string[]
---@param start_line number
---@param end_line number
---@param parent_indent number
---@return boolean
local function can_merge_between(lines, start_line, end_line, parent_indent)
  local saw_nested_content = false

  for line_num = start_line + 1, end_line - 1 do
    local line = lines[line_num] or ""
    if not line:match("^%s*$") then
      local list_info = parser.parse_list_line(line, line_num)
      if list_info then
        if #list_info.indent <= parent_indent then
          return false
        end
        saw_nested_content = true
      else
        local indent = #(line:match("^(%s*)") or "")
        if indent <= parent_indent then
          return false
        end
        saw_nested_content = true
      end
    end
  end

  return saw_nested_content
end

---Merge same-indent/type groups fragmented by nested children.
---@param groups table[]
---@param lines string[]
---@return table[]
local function merge_fragmented_groups(groups, lines)
  if #groups < 2 then
    return groups
  end

  local merged = {}
  for _, group in ipairs(groups) do
    local previous = merged[#merged]
    local can_merge = previous
      and previous.indent == group.indent
      and previous.list_type == group.list_type
      and #previous.items > 0
      and #group.items > 0

    if can_merge then
      local prev_end = previous.items[#previous.items].line_num
      local next_start = group.items[1].line_num
      if can_merge_between(lines, prev_end, next_start, previous.indent) then
        for _, item in ipairs(group.items) do
          table.insert(previous.items, item)
        end
      else
        table.insert(merged, group)
      end
    else
      table.insert(merged, group)
    end
  end

  return merged
end

---Find all distinct list groups in the buffer
---@param lines string[] All buffer lines
---@return table[] List of list groups
function M.find_list_groups(lines)
  local groups = {}
  local current_groups_by_indent = {} -- Track active groups by indentation level
  local code_block_lines, non_indented_regions = get_fenced_code_block_lines(lines)
  local html_block_lines = {}
  if html_awareness_enabled() then
    html_block_lines = utils.get_html_block_lines(lines)
  end

  for i, line in ipairs(lines) do
    if html_block_lines[i] then
      goto continue
    end

    if code_block_lines[i] then
      -- Non-indented (column 0) code blocks are structural separators per
      -- CommonMark — they break list continuity even without surrounding
      -- blank lines. Clear all active groups on first line of such a region.
      if non_indented_regions[i] and not non_indented_regions[i - 1] then
        current_groups_by_indent = {}
      end
      goto continue
    end

    local list_info = parser.parse_list_line(line)

    if list_info and shared.is_orderable_type(list_info.type) then
      local indent_level = #list_info.indent
      local list_type = list_info.type

      -- When we encounter a list item at a certain indent level,
      -- clear all groups at DEEPER indents
      for key, _ in pairs(current_groups_by_indent) do
        local group_indent = tonumber(key:match("^(%d+)_"))
        if group_indent and group_indent > indent_level then
          current_groups_by_indent[key] = nil
        end
      end

      -- Check if we have an active group at this indentation level and type
      local group_key = indent_level .. "_" .. list_type
      local current_group = current_groups_by_indent[group_key]

      if not current_group then
        -- Create new group for this indentation level and type
        current_group = {
          indent = indent_level,
          list_type = list_type,
          start_line = i,
          items = {},
        }
        current_groups_by_indent[group_key] = current_group
        table.insert(groups, current_group)
      end

      -- Add item to current group
      local content = shared.extract_list_content(line, list_info)

      table.insert(current_group.items, {
        line_num = i,
        indent = list_info.indent,
        checkbox = list_info.checkbox,
        content = content,
        original_line = line,
      })
    else
      -- Not an ordered/letter list item (could be unordered list or non-list content)
      if list_info then
        -- It's a valid list item but not orderable (e.g., unordered: -, *, +)
        -- Per CommonMark spec: different list marker types are separate lists
        -- An unordered item at indent N breaks orderable groups at indent >= N
        -- But does NOT break parent groups at shallower indents
        local unordered_indent = #list_info.indent
        for key, _ in pairs(current_groups_by_indent) do
          local group_indent = tonumber(key:match("^(%d+)_"))
          if group_indent and group_indent >= unordered_indent then
            current_groups_by_indent[key] = nil
          end
        end
      elseif M.is_list_breaking_line(line, i, lines) then
        -- Non-list content (blank line, paragraph, header, etc.)
        -- This breaks ALL groups at all indent levels
        current_groups_by_indent = {}
      end
    end

    ::continue::
  end

  return merge_fragmented_groups(groups, lines)
end

---Renumber items in a list group
---@param group table List group
---@return table|nil Changes or nil
function M.renumber_list_group(group)
  if #group.items == 0 then
    return nil
  end

  local changes = {}

  for idx, item in ipairs(group.items) do
    local checkbox_part = ""
    if item.checkbox then
      checkbox_part = " [" .. item.checkbox .. "]"
    end

    -- Determine expected marker based on list type
    local expected_marker = shared.get_marker_for_index(group.list_type, idx)

    local expected_line = item.indent .. expected_marker .. checkbox_part .. " " .. item.content

    -- Only create change if line is different
    if expected_line ~= item.original_line then
      table.insert(changes, {
        line_num = item.line_num,
        new_line = expected_line,
      })
    end
  end

  return #changes > 0 and changes or nil
end

---Cheap pre-filter to skip expensive parsing when no ordered list candidates exist
---@param lines string[]
---@return boolean
local function has_ordered_list_candidates(lines)
  for _, line in ipairs(lines) do
    for _, pattern in ipairs(ORDERED_LIST_CANDIDATE_PATTERNS) do
      if line:match(pattern) then
        return true
      end
    end
  end
  return false
end

---Apply line changes using contiguous batch writes
---@param changes {line_num: integer, new_line: string}[]
local function apply_changes(changes)
  table.sort(changes, function(a, b)
    return a.line_num < b.line_num
  end)

  local start_line = nil
  local end_line = nil
  local replacement_lines = {}

  local function flush_segment()
    if not start_line then
      return
    end
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, replacement_lines)
  end

  for _, change in ipairs(changes) do
    if not start_line then
      start_line = change.line_num
      end_line = change.line_num
      replacement_lines = { change.new_line }
    elseif change.line_num == end_line + 1 then
      end_line = change.line_num
      table.insert(replacement_lines, change.new_line)
    else
      flush_segment()
      start_line = change.line_num
      end_line = change.line_num
      replacement_lines = { change.new_line }
    end
  end

  flush_segment()
end

---Renumber all ordered lists in the buffer
function M.renumber_ordered_lists()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if not has_ordered_list_candidates(lines) then
    return
  end

  local modified = false
  local changes = {}

  -- Find all distinct list groups
  local list_groups = M.find_list_groups(lines)

  -- Renumber each list group
  for _, group in ipairs(list_groups) do
    local renumbered = M.renumber_list_group(group)
    if renumbered then
      modified = true
      for _, change in ipairs(renumbered) do
        table.insert(changes, change)
      end
    end
  end

  -- Apply changes if any were made
  if modified then
    apply_changes(changes)
  end
end

---Debug function to show detected list groups
function M.debug_list_groups()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local groups = M.find_list_groups(lines)

  print("=== Detected List Groups ===")
  for i, group in ipairs(groups) do
    print(string.format("Group %d (indent: %d, start: %d):", i, group.indent, group.start_line))
    for _, item in ipairs(group.items) do
      print(string.format("  Line %d: %s", item.line_num, item.original_line))
    end
    print()
  end
end

return M
