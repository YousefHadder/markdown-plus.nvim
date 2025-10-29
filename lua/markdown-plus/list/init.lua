-- List management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

-- Constants
local DELIMITER_DOT = "."
local DELIMITER_PAREN = ")"

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
}

-- Pattern configuration: defines order and metadata for pattern matching
local PATTERN_CONFIG = {
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
  { pattern = "ordered", type = "ordered", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_lower", type = "letter_lower", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "letter_upper", type = "letter_upper", delimiter = DELIMITER_DOT, has_checkbox = false },
  { pattern = "ordered_paren", type = "ordered_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_lower_paren", type = "letter_lower_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "letter_upper_paren", type = "letter_upper_paren", delimiter = DELIMITER_PAREN, has_checkbox = false },
  { pattern = "unordered", type = "unordered", delimiter = "", has_checkbox = false },
}

---Setup list management module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable list management features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for list management
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("ListEnter"),
      fn = M.handle_enter,
      modes = "i",
      default_key = "<CR>",
      desc = "Auto-continue list or break out",
    },
    {
      plug = keymap_helper.plug_name("ListIndent"),
      fn = M.handle_tab,
      modes = "i",
      default_key = "<Tab>",
      desc = "Indent list item",
    },
    {
      plug = keymap_helper.plug_name("ListOutdent"),
      fn = M.handle_shift_tab,
      modes = "i",
      default_key = "<S-Tab>",
      desc = "Outdent list item",
    },
    {
      plug = keymap_helper.plug_name("ListBackspace"),
      fn = M.handle_backspace,
      modes = "i",
      default_key = "<BS>",
      desc = "Smart backspace (remove empty list)",
    },
    {
      plug = keymap_helper.plug_name("RenumberLists"),
      fn = M.renumber_ordered_lists,
      modes = "n",
      default_key = "<leader>mr",
      desc = "Renumber ordered lists",
    },
    {
      plug = keymap_helper.plug_name("DebugLists"),
      fn = M.debug_list_groups,
      modes = "n",
      default_key = "<leader>md",
      desc = "Debug list groups",
    },
    {
      plug = keymap_helper.plug_name("NewListItemBelow"),
      fn = M.handle_normal_o,
      modes = "n",
      default_key = "o",
      desc = "New list item below",
    },
    {
      plug = keymap_helper.plug_name("NewListItemAbove"),
      fn = M.handle_normal_O,
      modes = "n",
      default_key = "O",
      desc = "New list item above",
    },
    {
      plug = keymap_helper.plug_name("ToggleCheckbox"),
      fn = {
        M.toggle_checkbox_line,
        M.toggle_checkbox_range,
        M.toggle_checkbox_insert,
      },
      modes = { "n", "x", "i" },
      default_key = { "<leader>mx", "<leader>mx", "<C-t>" },
      desc = "Toggle checkbox",
    },
  })

  -- Set up autocommands for auto-renumbering
  M.setup_renumber_autocmds()
end

---Set up autocommands for auto-renumbering
---@return nil
function M.setup_renumber_autocmds()
  local group = vim.api.nvim_create_augroup("MarkdownPlusListRenumber", { clear = true })

  -- Renumber on text changes (insertions/deletions)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = 0,
    callback = function()
      M.renumber_ordered_lists()
    end,
  })
end

-- Handle Enter key press
function M.handle_enter()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if we're in a list
  local list_info = M.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, simulate default Enter behavior
    -- Split the line at cursor position
    local line_before = current_line:sub(1, col)
    local line_after = current_line:sub(col + 1)

    utils.set_line(row, line_before)
    utils.insert_line(row + 1, line_after)
    utils.set_cursor(row + 1, 0)
    return
  end

  -- Check if current list item is empty
  if M.is_empty_list_item(current_line, list_info) then
    -- Empty list item - break out of list
    M.break_out_of_list(list_info)
    return
  end

  -- Create next list item
  M.create_next_list_item(list_info)
end

---Extract content from a list line after the marker
---@param line string The line to extract from
---@param list_info table List information
---@return string Content after the marker
local function extract_list_content(line, list_info)
  local marker_end = #list_info.indent + #list_info.full_marker
  return line:sub(marker_end + 1):match("^%s*(.*)") or ""
end

---Build list info object from pattern matches
---@param indent string Indentation
---@param marker string The marker (number, letter, or bullet)
---@param checkbox string|nil Checkbox state
---@param config table Pattern config
---@return table List info
local function build_list_info(indent, marker, checkbox, config)
  local full_marker = marker .. config.delimiter
  if config.has_checkbox then
    full_marker = full_marker .. " [" .. checkbox .. "]"
  end

  return {
    type = config.type,
    indent = indent,
    marker = marker .. config.delimiter,
    checkbox = config.has_checkbox and checkbox or nil,
    full_marker = full_marker,
  }
end

-- Parse a line to detect list information
function M.parse_list_line(line)
  if not line then
    return nil
  end

  -- Try each pattern in order (checkbox variants first, then regular)
  for _, config in ipairs(PATTERN_CONFIG) do
    local pattern = M.patterns[config.pattern]
    if config.has_checkbox then
      local indent, marker, checkbox = line:match(pattern)
      if indent and marker and checkbox then
        return build_list_info(indent, marker, checkbox, config)
      end
    else
      local indent, marker = line:match(pattern)
      if indent and marker then
        return build_list_info(indent, marker, nil, config)
      end
    end
  end

  return nil
end

-- Check if a list item is empty (only contains marker)
function M.is_empty_list_item(line, list_info)
  if not line or not list_info then
    return false
  end

  local content_pattern = "^" .. utils.escape_pattern(list_info.indent .. list_info.full_marker) .. "%s*$"
  return line:match(content_pattern) ~= nil
end

-- Break out of list (remove current empty item)
function M.break_out_of_list(list_info)
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Replace current line with just the indentation
  utils.set_line(row, list_info.indent)

  -- Position cursor at end of line
  utils.set_cursor(row, #list_info.indent)
end

---Convert index to single letter (1->a, 26->z, 27->a)
---@param idx number Index (1-based)
---@param is_upper boolean Whether to use uppercase
---@return string Single letter
function M.index_to_letter(idx, is_upper)
  local base = is_upper and string.byte("A") or string.byte("a")
  -- Wrap around after 26 letters
  local letter_idx = ((idx - 1) % 26)
  return string.char(base + letter_idx)
end

---Get next letter in sequence (a->b, z->a)
---@param letter string Current letter (single character)
---@param is_upper boolean Whether to use uppercase
---@return string Next letter in sequence
function M.next_letter(letter, is_upper)
  local byte = string.byte(letter)
  local base = is_upper and string.byte("A") or string.byte("a")
  local max = is_upper and string.byte("Z") or string.byte("z")

  if byte < max then
    return string.char(byte + 1)
  else
    -- Wrap around: z->a, Z->A
    return string.char(base)
  end
end

---Get the next marker for a list item
---@param list_info table List information
---@return string Next marker
local function get_next_marker(list_info)
  if list_info.type == "ordered" then
    local current_num = tonumber(list_info.marker:match("(%d+)"))
    return (current_num + 1) .. DELIMITER_DOT
  elseif list_info.type == "ordered_paren" then
    local current_num = tonumber(list_info.marker:match("(%d+)"))
    return (current_num + 1) .. DELIMITER_PAREN
  elseif list_info.type == "letter_lower" then
    local current_letter = list_info.marker:match("([a-z])")
    return M.next_letter(current_letter, false) .. DELIMITER_DOT
  elseif list_info.type == "letter_lower_paren" then
    local current_letter = list_info.marker:match("([a-z])")
    return M.next_letter(current_letter, false) .. DELIMITER_PAREN
  elseif list_info.type == "letter_upper" then
    local current_letter = list_info.marker:match("([A-Z])")
    return M.next_letter(current_letter, true) .. DELIMITER_DOT
  elseif list_info.type == "letter_upper_paren" then
    local current_letter = list_info.marker:match("([A-Z])")
    return M.next_letter(current_letter, true) .. DELIMITER_PAREN
  else
    -- Keep same bullet for unordered lists
    return list_info.marker
  end
end

---Get the previous/initial marker for inserting before current item
---@param list_info table Current list information
---@param row number Current row number
---@return string Previous marker
local function get_previous_marker(list_info, row)
  local is_ordered = list_info.type == "ordered" or list_info.type == "ordered_paren"
  local is_letter_lower = list_info.type == "letter_lower" or list_info.type == "letter_lower_paren"
  local is_letter_upper = list_info.type == "letter_upper" or list_info.type == "letter_upper_paren"
  local delimiter = list_info.marker:match("[%.%)]$")

  if is_ordered then
    -- Check for previous list item at same indent
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_num = tonumber(prev_list_info.marker:match("(%d+)"))
        return (prev_num + 1) .. delimiter
      end
    end
    return "1" .. delimiter
  elseif is_letter_lower then
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_letter = prev_list_info.marker:match("([a-z])")
        return M.next_letter(prev_letter, false) .. delimiter
      end
    end
    return "a" .. delimiter
  elseif is_letter_upper then
    if row > 1 then
      local prev_line = utils.get_line(row - 1)
      local prev_list_info = M.parse_list_line(prev_line)
      if prev_list_info and prev_list_info.type == list_info.type and #prev_list_info.indent == #list_info.indent then
        local prev_letter = prev_list_info.marker:match("([A-Z])")
        return M.next_letter(prev_letter, true) .. delimiter
      end
    end
    return "A" .. delimiter
  else
    -- Keep same bullet for unordered lists
    return list_info.marker
  end
end

-- Create next list item
function M.create_next_list_item(list_info)
  local cursor = utils.get_cursor()
  local row = cursor[1]

  local next_marker = get_next_marker(list_info)

  -- Build next line
  local next_line = list_info.indent .. next_marker .. " "
  if list_info.checkbox then
    next_line = next_line .. "[ ] "
  end

  -- Insert new line
  utils.insert_line(row + 1, next_line)

  -- Move cursor to new line at end
  utils.set_cursor(row + 1, #next_line)
end

-- Handle Tab key for indentation
function M.handle_tab()
  local current_line = utils.get_current_line()
  local list_info = M.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, insert a tab character or spaces
    local cursor = utils.get_cursor()
    local row, col = cursor[1], cursor[2]
    local indent = string.rep(" ", vim.bo.shiftwidth or 2)
    local new_line = current_line:sub(1, col) .. indent .. current_line:sub(col + 1)
    utils.set_line(row, new_line)
    utils.set_cursor(row, col + #indent)
    return
  end

  -- Increase indentation
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
  local indent_size = vim.bo.shiftwidth

  local new_indent = list_info.indent .. string.rep(" ", indent_size)
  -- Extract content after the marker (position-based to avoid pattern issues with parentheses)
  local content = extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. content

  utils.set_line(row, new_line)

  -- Adjust cursor position
  utils.set_cursor(row, col + indent_size)
end

-- Handle Shift+Tab key for outdentation
function M.handle_shift_tab()
  local current_line = utils.get_current_line()
  local list_info = M.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, remove indentation if any
    local cursor = utils.get_cursor()
    local row, col = cursor[1], cursor[2]
    local indent_size = vim.bo.shiftwidth or 2
    local leading_spaces = current_line:match("^(%s*)")

    if #leading_spaces >= indent_size then
      local new_line = current_line:sub(indent_size + 1)
      utils.set_line(row, new_line)
      utils.set_cursor(row, math.max(0, col - indent_size))
    end
    return
  end

  -- Decrease indentation
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]
  local indent_size = vim.bo.shiftwidth

  if #list_info.indent < indent_size then
    -- Can't outdent further
    return
  end

  local new_indent = list_info.indent:sub(1, -indent_size - 1)
  -- Extract content after the marker (position-based to avoid pattern issues with parentheses)
  local content = extract_list_content(current_line, list_info)
  local new_line = new_indent .. list_info.full_marker .. " " .. (content or "")

  utils.set_line(row, new_line)

  -- Adjust cursor position
  local new_col = math.max(0, col - indent_size)
  utils.set_cursor(row, new_col)
end

-- Handle Backspace key for smart list removal
function M.handle_backspace()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row, col = cursor[1], cursor[2]

  -- Check if cursor is at the beginning of list content
  local list_info = M.parse_list_line(current_line)
  if not list_info then
    -- Not in a list, delete character before cursor
    if col > 0 then
      local new_line = current_line:sub(1, col - 1) .. current_line:sub(col + 1)
      utils.set_line(row, new_line)
      utils.set_cursor(row, col - 1)
    elseif row > 1 then
      -- At beginning of line, join with previous line
      local prev_line = utils.get_line(row - 1)
      local joined = prev_line .. current_line
      vim.api.nvim_buf_set_lines(0, row - 2, row, false, { joined })
      utils.set_cursor(row - 1, #prev_line)
    end
    return
  end

  local marker_end = #list_info.indent + #list_info.full_marker + 1
  if col == marker_end and M.is_empty_list_item(current_line, list_info) then
    -- At the beginning of empty list item, remove the list marker
    utils.set_line(row, list_info.indent)
    utils.set_cursor(row, #list_info.indent)
    return
  end

  -- Default backspace in list item
  if col > 0 then
    local new_line = current_line:sub(1, col - 1) .. current_line:sub(col + 1)
    utils.set_line(row, new_line)
    utils.set_cursor(row, col - 1)
  end
end

-- Handle normal mode 'o' key
function M.handle_normal_o()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item
  local list_info = M.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, use default 'o' behavior
    -- Create blank line below and enter insert mode
    utils.insert_line(row + 1, "")
    utils.set_cursor(row + 1, 0)
    vim.cmd("startinsert")
    return
  end

  -- Create next list item and enter insert mode
  local next_marker = get_next_marker(list_info)

  -- Build next line
  local next_line = list_info.indent .. next_marker .. " "
  if list_info.checkbox then
    next_line = next_line .. "[ ] "
  end

  -- Insert new line after current
  utils.insert_line(row + 1, next_line)

  -- Move cursor to new line at end and enter insert mode
  utils.set_cursor(row + 1, #next_line)
  vim.cmd("startinsert!")
end

-- Handle normal mode 'O' key
function M.handle_normal_O()
  local current_line = utils.get_current_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]

  -- Check if current line is a list item
  local list_info = M.parse_list_line(current_line)

  if not list_info then
    -- Not in a list, use default 'O' behavior
    -- Create blank line above and enter insert mode
    utils.insert_line(row, "")
    utils.set_cursor(row, 0)
    vim.cmd("startinsert")
    return
  end

  -- For 'O', we need to create a list item before the current one
  -- This means we need to determine what the previous marker should be
  local prev_marker = get_previous_marker(list_info, row)

  -- Build previous line
  local prev_line = list_info.indent .. prev_marker .. " "
  if list_info.checkbox then
    prev_line = prev_line .. "[ ] "
  end

  -- Insert new line before current
  utils.insert_line(row, prev_line)

  -- Move cursor to new line at end and enter insert mode
  utils.set_cursor(row, #prev_line)
  vim.cmd("startinsert!")
end

-- Renumber all ordered lists in the buffer
function M.renumber_ordered_lists()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
    for _, change in ipairs(changes) do
      utils.set_line(change.line_num, change.new_line)
    end
  end
end

-- Find all distinct list groups in the buffer
function M.find_list_groups(lines)
  local groups = {}
  local current_groups_by_indent = {} -- Track active groups by indentation level

  for i, line in ipairs(lines) do
    local list_info = M.parse_list_line(line)

    if
      list_info
      and (
        list_info.type == "ordered"
        or list_info.type == "letter_lower"
        or list_info.type == "letter_upper"
        or list_info.type == "ordered_paren"
        or list_info.type == "letter_lower_paren"
        or list_info.type == "letter_upper_paren"
      )
    then
      local indent_level = #list_info.indent
      local list_type = list_info.type

      -- When we encounter a list item at a certain indent level,
      -- clear all groups at DEEPER indents (numerically greater than current level) to ensure nested lists
      -- restart numbering when returning to a parent level
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
      -- Extract content after the full marker
      local content = extract_list_content(line, list_info)

      table.insert(current_group.items, {
        line_num = i,
        indent = list_info.indent,
        checkbox = list_info.checkbox,
        content = content,
        original_line = line,
      })
    else
      -- Not an ordered/letter list item
      -- Check if this line breaks the list continuity
      if M.is_list_breaking_line(line) then
        -- Clear all active groups (lists are separated by non-list content)
        current_groups_by_indent = {}
      end
    end
  end

  return groups
end

-- Check if a line breaks list continuity
function M.is_list_breaking_line(line)
  -- Empty lines terminate list groups (causing subsequent lists to restart numbering from 1 or a)
  if not line or line:match("^%s*$") then
    return true
  end

  -- Any non-list content breaks list continuity
  -- This includes headers, paragraphs, etc.
  return true
end

-- Renumber items in a list group
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
    local expected_marker
    if group.list_type == "ordered" then
      expected_marker = idx .. DELIMITER_DOT
    elseif group.list_type == "ordered_paren" then
      expected_marker = idx .. DELIMITER_PAREN
    elseif group.list_type == "letter_lower" then
      expected_marker = M.index_to_letter(idx, false) .. DELIMITER_DOT
    elseif group.list_type == "letter_lower_paren" then
      expected_marker = M.index_to_letter(idx, false) .. DELIMITER_PAREN
    elseif group.list_type == "letter_upper" then
      expected_marker = M.index_to_letter(idx, true) .. DELIMITER_DOT
    elseif group.list_type == "letter_upper_paren" then
      expected_marker = M.index_to_letter(idx, true) .. DELIMITER_PAREN
    end

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

-- Debug function to show detected list groups
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

-- ============================================================================
-- Checkbox Management
-- ============================================================================

--- Toggle checkbox on a specific line
---@param line_num number 1-indexed line number
---@return nil
function M.toggle_checkbox_on_line(line_num)
  local line = utils.get_line(line_num)
  if line == "" then
    return
  end

  local list_info = M.parse_list_line(line)

  if not list_info then
    return -- Not a list item, do nothing
  end

  local new_line = M.toggle_checkbox_in_line(line, list_info)
  if new_line then
    utils.set_line(line_num, new_line)
  end
end

--- Toggle checkbox state in a line
---@param line string The line content
---@param list_info table The parsed list information
---@return string|nil The modified line, or nil if no change
function M.toggle_checkbox_in_line(line, list_info)
  if list_info.checkbox then
    -- Has checkbox - toggle between checked/unchecked
    return M.replace_checkbox_state(line, list_info)
  else
    -- No checkbox - add one
    return M.add_checkbox_to_line(line, list_info)
  end
end

--- Replace checkbox state in a line
---@param line string The line content
---@param list_info table The parsed list information
---@return string The modified line
function M.replace_checkbox_state(line, list_info)
  local indent = list_info.indent
  local marker = list_info.marker

  -- Find the checkbox pattern and extract the content after it
  local checkbox_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)%[.?%]%s*(.*)"

  local prefix, content = line:match(checkbox_pattern)

  if prefix and content ~= nil then
    local current_state = list_info.checkbox
    local new_state = (current_state == "x" or current_state == "X") and " " or "x"
    return prefix .. "[" .. new_state .. "] " .. content
  end

  return line
end

--- Add checkbox to a line that doesn't have one
---@param line string The line content
---@param list_info table The parsed list information
---@return string The modified line
function M.add_checkbox_to_line(line, list_info)
  local indent = list_info.indent
  local marker = list_info.marker

  -- Pattern to match list item and capture content
  local list_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)(.*)"

  local prefix, content = line:match(list_pattern)

  if prefix and content ~= nil then
    return prefix .. "[ ] " .. content
  end

  return line
end

--- Toggle checkbox on current line (normal mode)
---@return nil
function M.toggle_checkbox_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  M.toggle_checkbox_on_line(row)
end

--- Toggle checkbox in visual range
---@return nil
function M.toggle_checkbox_range()
  local start_row = vim.fn.line("v")
  local end_row = vim.fn.line(".")

  if start_row == 0 or end_row == 0 then
    return
  end

  -- Ensure start is before end
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  for row = start_row, end_row do
    M.toggle_checkbox_on_line(row)
  end
end

--- Toggle checkbox in insert mode (maintains cursor position)
---@return nil
function M.toggle_checkbox_insert()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  local col = cursor[2]

  local old_line = utils.get_line(row)
  M.toggle_checkbox_on_line(row)

  -- Restore cursor position (adjusting for potential line length changes)
  local new_line = utils.get_line(row)

  -- Calculate the character delta to adjust cursor position
  local old_len = #old_line
  local new_len = #new_line
  local delta = new_len - old_len

  local new_col
  -- Adjust cursor position by the delta to maintain visual position
  if delta > 0 then
    -- Characters were added (e.g., checkbox added), move cursor forward
    new_col = math.min(col + delta, #new_line)
  elseif delta < 0 then
    -- Characters were removed (e.g., checkbox removed), move cursor backward
    new_col = math.max(0, col + delta)
    new_col = math.min(new_col, #new_line)
  else
    -- No change in length (e.g., toggling checkbox state)
    new_col = math.min(col, #new_line)
  end

  vim.api.nvim_win_set_cursor(0, { row, new_col })
end

return M
