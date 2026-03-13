-- Normal mode and backspace handlers for list management
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local handler_utils = require("markdown-plus.list.handler_utils")

local M = {}

---Set module configuration (reserved for future use; keeps facade propagation uniform)
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg) -- luacheck: no unused args
  -- Normal handler currently delegates all config-dependent behavior to handler_utils.
  -- This stub keeps the set_config interface uniform across all handler sub-modules.
end

---Delete the character before the cursor (UTF-8 safe)
---@param line string Current line content
---@param row number Current row (1-indexed)
---@param col number Current column (0-indexed byte offset)
---@return nil
local function delete_prev_char(line, row, col)
  local char_idx = vim.fn.charidx(line, col)
  local prev_char_idx = char_idx - 1
  if prev_char_idx < 0 then
    return
  end
  local new_col = vim.fn.byteidx(line, prev_char_idx)
  vim.api.nvim_buf_set_text(0, row - 1, new_col, row - 1, col, { "" })
  utils.set_cursor(row, new_col)
end

---Handle Backspace key
---@return nil
function M.handle_backspace()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, default backspace behavior
    if col > 0 then
      delete_prev_char(current_line, row, col)
    elseif row > 1 then
      -- At start of line, join with previous line
      local prev_line = utils.get_line(row - 1)
      local joined_line = prev_line .. current_line
      vim.api.nvim_buf_set_lines(0, row - 2, row, false, { joined_line })
      utils.set_cursor(row - 1, #prev_line)
    end
    return
  end

  -- If at the start of list content, remove the list marker
  local marker_end_col = #list_info.indent + #list_info.full_marker + 1
  if col <= marker_end_col and col > #list_info.indent then
    -- Remove list marker, keep content
    local content = shared.extract_list_content(current_line, list_info)
    utils.set_line(row, list_info.indent .. content)
    utils.set_cursor(row, #list_info.indent)
    return
  end

  -- Default backspace in list content
  if col > 0 then
    delete_prev_char(current_line, row, col)
  end
end

---Check whether the given row is the last list item at its indentation level
---@param row number Current row (1-indexed)
---@param indent_level number Indentation width in spaces
---@param lines table<number, string> Sparse absolute-row line map
---@param max_scan_row number Maximum row to scan forward
---@return boolean
local function is_last_item_at_indent(row, indent_level, lines, max_scan_row)
  for i = row + 1, max_scan_row do
    local line = lines[i]
    if not line then
      return true
    end

    local next_list = parser.parse_list_line(line, i)
    if next_list then
      local next_indent = #next_list.indent
      if next_indent == indent_level then
        return false
      end
      if next_indent < indent_level then
        return true
      end
    else
      if line:match("^%s*$") then
        return true
      end

      local line_indent = #(line:match("^(%s*)") or "")
      if line_indent <= indent_level then
        return true
      end
    end
  end

  -- We intentionally bound scanning for performance and assume "last item"
  -- when no sibling or break is found in the lookahead window.
  return true
end

---Handle normal mode 'o' key
---@return nil
function M.handle_normal_o()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, insert blank line below and enter insert mode
    utils.insert_line(row + 1, "")
    utils.set_cursor(row + 1, 0)
    vim.cmd("startinsert")
    return
  end

  if handler_utils.smart_outdent_enabled() then
    local current_indent = #list_info.indent
    local indent_size = vim.fn.shiftwidth()
    local lines, line_count = handler_utils.get_context_lines(row)
    local max_scan_row = math.min(line_count, row + handler_utils.MAX_LAST_ITEM_LOOKAHEAD)

    if current_indent > 0 and is_last_item_at_indent(row, current_indent, lines, max_scan_row) then
      local target_indent = math.max(0, current_indent - indent_size)
      local parent_list = shared.find_parent_list_at_indent(row, target_indent, lines)

      if parent_list then
        local next_parent_marker = parser.get_next_marker(parent_list)
        local next_parent_line =
          handler_utils.build_list_prefix(parent_list.indent, next_parent_marker, parent_list.checkbox)

        utils.insert_line(row + 1, next_parent_line)
        utils.set_cursor(row + 1, #next_parent_line)
        vim.cmd("startinsert!")
        return
      end
    end
  end

  -- Create next list item below
  local next_marker = parser.get_next_marker(list_info)
  local next_line = handler_utils.build_list_prefix(list_info.indent, next_marker, list_info.checkbox)

  utils.insert_line(row + 1, next_line)
  utils.set_cursor(row + 1, #next_line)
  vim.cmd("startinsert!")
end

---Handle normal mode 'O' key
---@return nil
function M.handle_normal_O()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item (pass row for treesitter parsing)
  local list_info = parser.parse_list_line(current_line, row)

  if not list_info then
    -- Not in a list, insert blank line above and enter insert mode
    utils.insert_line(row, "")
    utils.set_cursor(row, 0)
    vim.cmd("startinsert")
    return
  end

  -- Insert list item above with previous marker
  local prev_marker = parser.get_previous_marker(list_info, row)
  local prev_line = handler_utils.build_list_prefix(list_info.indent, prev_marker, list_info.checkbox)

  utils.insert_line(row, prev_line)
  utils.set_cursor(row, #prev_line)
  vim.cmd("startinsert!")
end

return M
