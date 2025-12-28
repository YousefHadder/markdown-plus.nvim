-- Checkbox management module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local parser = require("markdown-plus.list.parser")
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

---Toggle checkbox on a specific line
---@param line_num number 1-indexed line number
function M.toggle_checkbox_on_line(line_num)
  local line = utils.get_line(line_num)
  if line == "" then
    return
  end

  local list_info = parser.parse_list_line(line)

  if not list_info then
    return -- Not a list item, do nothing
  end

  local new_line = M.toggle_checkbox_in_line(line, list_info)
  if new_line then
    utils.set_line(line_num, new_line)
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
  local indent = list_info.indent
  local marker = list_info.marker
  local config = M.get_completion_config()

  -- Find the checkbox pattern and extract the content after it
  local checkbox_pattern = "^(" .. utils.escape_pattern(indent) .. utils.escape_pattern(marker) .. "%s*)%[.?%]%s*(.*)"

  local prefix, content = line:match(checkbox_pattern)

  if prefix and content ~= nil then
    local current_state = list_info.checkbox
    local is_checking = not (current_state == "x" or current_state == "X")
    local new_state = is_checking and "x" or " "

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

    return prefix .. "[" .. new_state .. "] " .. content
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
    return prefix .. "[ ] " .. content
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

  for row = start_row, end_row do
    M.toggle_checkbox_on_line(row)
  end
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
