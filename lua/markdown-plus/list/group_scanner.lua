-- List group scanning module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local code_block_parser = require("markdown-plus.code_block.parser")
local M = {}

local html_awareness = true

---Set HTML block awareness state
---@param enabled boolean
function M.set_html_awareness(enabled)
  html_awareness = enabled ~= false
end

---Build set of 1-indexed line numbers inside fenced code blocks.
---Absorbs adjacent blank lines for indented fences (nested in list items).
---Marks non-indented code block regions as structural separators.
---@param lines string[] All buffer lines
---@return table<number, boolean> code_lines
---@return table<number, boolean> non_indented_regions
local function get_fenced_code_block_lines(lines)
  local code_lines = {}
  local non_indented_regions = {}
  local active_fence = nil
  local block_start = nil

  for i, line in ipairs(lines) do
    if not active_fence then
      local opening = code_block_parser.parse_opening_fence(line)
      if opening then
        code_lines[i] = true
        active_fence = {
          fence_char = opening.fence_char,
          fence_length = opening.fence_length,
        }
        block_start = i
        -- Only column-0 fences are structural separators
        if #opening.indent == 0 then
          non_indented_regions[i] = true
        end
      end
    else
      code_lines[i] = true
      -- Propagate non-indented flag to all lines in block
      if non_indented_regions[block_start] then
        non_indented_regions[i] = true
      end
      local closing = code_block_parser.parse_closing_fence(line, active_fence)
      if closing then
        active_fence = nil
        block_start = nil
      end
    end
  end

  -- Absorb adjacent blank lines for indented fences only
  local expanded = {}
  for k, v in pairs(code_lines) do
    expanded[k] = v
  end
  for i = 1, #lines do
    if code_lines[i] and not code_lines[i - 1] then
      if not non_indented_regions[i] then
        local j = i - 1
        while j >= 1 and lines[j]:match("^%s*$") do
          expanded[j] = true
          j = j - 1
        end
      end
    end
    if code_lines[i] and not code_lines[i + 1] then
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
---@param line string|nil
---@param line_num number|nil 1-indexed line number (provide with `lines` for continuation checks)
---@param lines string[]|nil All buffer lines (provide with `line_num` for continuation checks)
---@return boolean
function M.is_list_breaking_line(line, line_num, lines)
  if not line then
    return true
  end

  if line:match("^%s*$") then
    if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
      return false
    end
    return true
  end

  if parser.parse_list_line(line, line_num) then
    return false
  end

  if line_num and lines and shared.is_continuation_line(line, line_num, lines) then
    return false
  end

  return true
end

---Check whether groups can be merged without crossing structural separators
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

---Merge same-indent/type groups fragmented by nested children
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
  local current_groups_by_indent = {}
  local code_block_lines, non_indented_regions = get_fenced_code_block_lines(lines)
  local html_block_lines = {}
  if html_awareness then
    html_block_lines = utils.get_html_block_lines(lines)
  end

  for i, line in ipairs(lines) do
    if html_block_lines[i] then
      goto continue
    end
    if code_block_lines[i] then
      -- Non-indented code blocks break list continuity (CommonMark)
      if non_indented_regions[i] and not non_indented_regions[i - 1] then
        current_groups_by_indent = {}
      end
      goto continue
    end
    local list_info = parser.parse_list_line(line)
    if list_info and shared.is_orderable_type(list_info.type) then
      local indent_level = #list_info.indent
      local list_type = list_info.type
      -- Clear all groups at DEEPER indents
      for key, _ in pairs(current_groups_by_indent) do
        local group_indent = tonumber(key:match("^(%d+)_"))
        if group_indent and group_indent > indent_level then
          current_groups_by_indent[key] = nil
        end
      end

      local group_key = indent_level .. "_" .. list_type
      local current_group = current_groups_by_indent[group_key]
      if not current_group then
        current_group = {
          indent = indent_level,
          list_type = list_type,
          start_line = i,
          items = {},
        }
        current_groups_by_indent[group_key] = current_group
        table.insert(groups, current_group)
      end

      local content = shared.extract_list_content(line, list_info)
      table.insert(current_group.items, {
        line_num = i,
        indent = list_info.indent,
        checkbox = list_info.checkbox,
        content = content,
        original_line = line,
      })
    else
      if list_info then
        -- Unordered item at indent N breaks orderable groups at indent >= N
        local unordered_indent = #list_info.indent
        for key, _ in pairs(current_groups_by_indent) do
          local group_indent = tonumber(key:match("^(%d+)_"))
          if group_indent and group_indent >= unordered_indent then
            current_groups_by_indent[key] = nil
          end
        end
      elseif M.is_list_breaking_line(line, i, lines) then
        current_groups_by_indent = {}
      end
    end

    ::continue::
  end

  return merge_fragmented_groups(groups, lines)
end

return M
