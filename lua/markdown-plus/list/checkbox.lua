-- Checkbox management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
local shared = require("markdown-plus.list.shared")
local checkbox_sync = require("markdown-plus.list.checkbox_sync")
local M = {}

---@type markdown-plus.InternalListConfig|nil
M.config = nil

---Setup checkbox module with configuration
---@param config markdown-plus.InternalListConfig|nil List configuration
function M.setup(config)
  M.config = config
end

---Get checkbox completion config with defaults
---@return markdown-plus.InternalCheckboxCompletionConfig
function M.get_completion_config()
  -- Try to get config from main plugin first (allows runtime changes)
  local ok, markdown_plus = pcall(require, "markdown-plus")
  if ok and markdown_plus.config and markdown_plus.config.list and markdown_plus.config.list.checkbox_completion then
    return markdown_plus.config.list.checkbox_completion
  end
  -- Fall back to module config if set
  if M.config and M.config.checkbox_completion then
    return M.config.checkbox_completion
  end
  -- Return defaults if no config available
  return {
    enabled = false,
    format = "emoji",
    date_format = "%Y-%m-%d",
    remove_on_uncheck = true,
    update_existing = true,
  }
end

-- Timestamp format definitions
-- Each format has:
--   template: function to generate the timestamp string
--   pattern: Lua pattern to match existing timestamps (for removal/update)
-- Note: Patterns are specific to common date formats to avoid matching arbitrary text.
--       Default pattern matches ISO 8601 (YYYY-MM-DD) and common variants with time.
--       Custom date_format values should use similar numeric date structures.
local TIMESTAMP_FORMATS = {
  emoji = {
    template = function(date)
      return " ✅ " .. date
    end,
    -- Match: " ✅ YYYY-MM-DD" or " ✅ DD/MM/YYYY" or with time (HH:MM, HH:MM:SS)
    pattern = " ✅ %d%d%d?%d?[%-%/%.:]%d%d[%-%/%.:]%d%d%d?%d?[%s%d:]*$",
  },
  comment = {
    template = function(date)
      return " <!-- completed: " .. date .. " -->"
    end,
    -- Match: " <!-- completed: YYYY-MM-DD -->" or with time
    pattern = " <!%-%- completed: %d%d%d?%d?[%-%/%.:]%d%d[%-%/%.:]%d%d%d?%d?[%s%d:]* %-%->$",
  },
  dataview = {
    template = function(date)
      return " [completion:: " .. date .. "]"
    end,
    -- Match: " [completion:: YYYY-MM-DD]" or with time
    pattern = " %[completion:: %d%d%d?%d?[%-%/%.:]%d%d[%-%/%.:]%d%d%d?%d?[%s%d:]*%]$",
  },
  parenthetical = {
    template = function(date)
      return " (completed: " .. date .. ")"
    end,
    -- Match: " (completed: YYYY-MM-DD)" or with time
    pattern = " %(completed: %d%d%d?%d?[%-%/%.:]%d%d[%-%/%.:]%d%d%d?%d?[%s%d:]*%)$",
  },
}

---Generate a completion timestamp string
---@param config markdown-plus.InternalCheckboxCompletionConfig
---@return string The formatted timestamp string
local function generate_timestamp(config)
  local format_def = TIMESTAMP_FORMATS[config.format]
  if not format_def then
    return ""
  end
  -- os.date() returns nil for invalid format strings; fall back to empty string
  local date = os.date(config.date_format) or ""
  return format_def.template(date)
end

---Remove any completion timestamp from content
---@param content string The content to clean
---@return string The content without timestamp
local function remove_timestamp(content)
  -- Try to remove any known timestamp format
  for _, format_def in pairs(TIMESTAMP_FORMATS) do
    local cleaned = content:gsub(format_def.pattern, "")
    if cleaned ~= content then
      return cleaned
    end
  end
  return content
end

---Check if content has an existing timestamp
---@param content string The content to check
---@return boolean has_timestamp Whether a timestamp exists
---@return string|nil format_name The format name if found
local function has_timestamp(content)
  for name, format_def in pairs(TIMESTAMP_FORMATS) do
    if content:match(format_def.pattern) then
      return true, name
    end
  end
  return false, nil
end

---Write a rewritten list line back to the buffer.
---The checkbox prefix is edited separately from optional timestamps around unchanged content.
---@param line_num number 1-indexed line number
---@param line string The current line content
---@param list_info markdown-plus.ListInfo The parsed list information for `line`
---@param new_line string The rewritten line
---@return boolean written Whether the line was written
local function write_list_line(line_num, line, list_info, new_line)
  local prefix = line:match("^" .. utils.escape_pattern(list_info.indent .. list_info.marker) .. "%s*")
  if not prefix then
    vim.notify("markdown-plus: Could not locate the checkbox prefix", vim.log.levels.ERROR)
    return false
  end

  local row = line_num - 1
  if list_info.checkbox then
    local state_col = #prefix + 1
    vim.api.nvim_buf_set_text(0, row, state_col, row, state_col + #list_info.checkbox, {
      new_line:sub(state_col + 1, state_col + 1),
    })
    local spacing_col = #prefix + 3
    local old_spacing_col = #prefix + #list_info.checkbox + 2
    local old_spacing = line:sub(old_spacing_col + 1):match("^%s*") or ""
    local new_spacing = new_line:sub(spacing_col + 1):match("^%s*") or ""
    if old_spacing ~= new_spacing then
      vim.api.nvim_buf_set_text(0, row, spacing_col, row, spacing_col + #old_spacing, { new_spacing })
    end
  else
    local added = #new_line - #line
    vim.api.nvim_buf_set_text(0, row, #prefix, row, #prefix, { new_line:sub(#prefix + 1, #prefix + added) })
  end
  utils.set_line(line_num, new_line)
  return true
end

---Toggle the checkbox on a line without syncing parents or children
---@param line_num number 1-indexed line number
---@return markdown-plus.list.CheckboxChange|nil change The toggled item, or nil if nothing changed
local function toggle_line(line_num)
  local line = utils.get_line(line_num)
  if line == "" then
    return nil
  end

  local list_info = parser.parse_list_line(line, line_num)

  if not list_info then
    return nil -- Not a list item, do nothing
  end

  local new_line = M.toggle_checkbox_in_line(line, list_info)
  if new_line and new_line ~= line and write_list_line(line_num, line, list_info, new_line) then
    return { row = line_num, added = list_info.checkbox == nil }
  end
  return nil
end

---Check whether toggling a checkbox also updates its parents and children
---@return boolean
function M.is_sync_enabled()
  -- Read the main plugin config first (allows runtime changes), then the module config
  local ok, markdown_plus = pcall(require, "markdown-plus")
  if ok and markdown_plus.config and markdown_plus.config.list and markdown_plus.config.list.checkbox_sync ~= nil then
    return markdown_plus.config.list.checkbox_sync
  end
  return M.config ~= nil and M.config.checkbox_sync == true
end

---Set the checkbox state of the list item on a specific line
---@param line_num number 1-indexed line number
---@param state string New checkbox state
---@return boolean changed Whether the line changed
function M.set_checkbox_state_on_line(line_num, state)
  local line = utils.get_line(line_num)
  local list_info = parser.parse_list_line(line, line_num)
  if not list_info or not list_info.checkbox then
    return false
  end

  local new_line = M.set_checkbox_state_in_line(line, list_info, state)
  return new_line ~= line and write_list_line(line_num, line, list_info, new_line)
end

---Update parents and children of toggled items when `list.checkbox_sync` is enabled
---
---With `opts.undojoin`, the updates join the undo block of the edit that caused them, so one
---`u` reverts both.
---@param changes markdown-plus.list.CheckboxChange[] Toggled or moved list items
---@param opts? { undojoin?: boolean }
---@return nil
function M.sync_checkboxes(changes, opts)
  if #changes == 0 or not M.is_sync_enabled() then
    return
  end

  -- Edits not synced yet (e.g. an indent typed just before toggling) are synced along
  local edits = require("markdown-plus.list.checkbox_autocmds")
  local bufnr = vim.api.nvim_get_current_buf()
  changes = vim.list_extend(vim.list_extend({}, changes), edits.take_changes(bufnr))

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local updates = checkbox_sync.plan(lines, changes)
  if #updates > 0 and opts and opts.undojoin then
    -- Fails with E790 right after an undo; the updates then simply get their own undo step
    pcall(vim.cmd, "undojoin")
  end
  for _, update in ipairs(updates) do
    M.set_checkbox_state_on_line(update.row, update.state)
  end
  edits.refresh(bufnr)
end

---Toggle checkbox on a specific line
---@param line_num number 1-indexed line number
---@return nil
function M.toggle_checkbox_on_line(line_num)
  local change = toggle_line(line_num)
  if change then
    M.sync_checkboxes({ change })
  end
end

---Toggle checkbox state in a line
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

---Replace checkbox state in a line
---@param line string The line content
---@param list_info table The parsed list information
---@return string The modified line
function M.replace_checkbox_state(line, list_info)
  local new_state = checkbox_sync.is_checked(list_info.checkbox) and " " or "x"
  return M.set_checkbox_state_in_line(line, list_info, new_state)
end

---Set the checkbox state in a line, adding or removing completion timestamps as configured
---@param line string The line content
---@param list_info table The parsed list information
---@param new_state string The checkbox state to write
---@return string The modified line
function M.set_checkbox_state_in_line(line, list_info, new_state)
  local indent = list_info.indent
  local marker = list_info.marker
  local config = M.get_completion_config()

  -- Find the checkbox pattern and extract the content after it
  local checkbox_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)%[.?%]%s*(.*)"

  local prefix, content = line:match(checkbox_pattern)

  if prefix and content ~= nil then
    local is_checking = checkbox_sync.is_checked(new_state)

    -- Handle completion timestamps
    if config.enabled then
      local existing_timestamp = has_timestamp(content)

      if is_checking then
        -- Checking the task
        if existing_timestamp then
          if config.update_existing then
            -- Remove old timestamp and add new one
            content = remove_timestamp(content)
            -- Trim trailing whitespace before adding new timestamp
            content = content:gsub("%s+$", "")
            content = content .. generate_timestamp(config)
          end
          -- If not update_existing, keep the old timestamp as-is
        else
          -- No existing timestamp, add one
          -- Trim trailing whitespace before adding timestamp
          content = content:gsub("%s+$", "")
          content = content .. generate_timestamp(config)
        end
      else
        -- Unchecking the task
        if existing_timestamp and config.remove_on_uncheck then
          content = remove_timestamp(content)
          -- Trim trailing whitespace after removing timestamp
          content = content:gsub("%s+$", "")
        end
        -- If not remove_on_uncheck, keep the timestamp
      end
    end

    -- Honor the configured marker→content spacing. The full marker includes the
    -- checkbox bracket; spaces_after_marker returns a single space in "single"
    -- mode, so this is byte-identical to the historical layout by default.
    local full_marker = prefix:sub(#indent + 1) .. "[" .. new_state .. "]"
    return prefix .. "[" .. new_state .. "]" .. shared.spaces_after_marker(full_marker) .. content
  end

  return line
end

---Add checkbox to a line that doesn't have one
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
    -- Pad to the configured block (single space in "single" mode → unchanged).
    local full_marker = prefix:sub(#indent + 1) .. "[ ]"
    return prefix .. "[ ]" .. shared.spaces_after_marker(full_marker) .. content
  end

  return line
end

---Toggle checkbox on current line (normal mode)
function M.toggle_checkbox_line()
  local cursor = utils.get_cursor()
  local row = cursor[1]
  M.toggle_checkbox_on_line(row)
end

---Toggle checkbox in visual range
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

  -- Toggle every line first so selected items keep the state they toggled to, then sync once
  local changes = {}
  for row = start_row, end_row do
    local change = toggle_line(row)
    if change then
      table.insert(changes, change)
    end
  end
  M.sync_checkboxes(changes)
end

---Toggle checkbox in insert mode (maintains cursor position)
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
