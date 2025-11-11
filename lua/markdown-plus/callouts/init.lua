-- Callouts (admonitions) module for markdown-plus.nvim
-- Supports GitHub Flavored Markdown callout syntax
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

-- GFM callout types (in cycling order)
-- Base types that are always available
local BASE_CALLOUT_TYPES = {
  "NOTE",
  "TIP",
  "IMPORTANT",
  "WARNING",
  "CAUTION",
}

M.CALLOUT_TYPES = vim.deepcopy(BASE_CALLOUT_TYPES)

-- Pattern matching
local CALLOUT_START = "^%s*>%s*%[!([A-Z]+)%]"
local BLOCKQUOTE_LINE = "^%s*>%s?(.*)$"

--- Setup callouts module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}

  -- Reset to base types
  M.CALLOUT_TYPES = vim.deepcopy(BASE_CALLOUT_TYPES)

  -- Merge custom types if configured
  if M.config.callouts and M.config.callouts.custom_types then
    for _, custom_type in ipairs(M.config.callouts.custom_types) do
      if not vim.tbl_contains(M.CALLOUT_TYPES, custom_type) then
        table.insert(M.CALLOUT_TYPES, custom_type)
      end
    end
  end
end

--- Enable callouts features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end
  M.setup_keymaps()
end

--- Set up keymaps for callout management
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("InsertCallout"),
      fn = {
        M.insert_callout_prompt,
        M.wrap_selection_in_callout,
      },
      modes = { "n", "x" },
      default_key = { "<leader>mQi", "<leader>mQi" },
      desc = "Insert/wrap callout",
    },
    {
      plug = keymap_helper.plug_name("ToggleCalloutType"),
      fn = M.toggle_callout_type,
      modes = { "n" },
      default_key = "<leader>mQt",
      desc = "Toggle callout type",
    },
    {
      plug = keymap_helper.plug_name("ConvertToCallout"),
      fn = M.convert_to_callout,
      modes = { "n" },
      default_key = "<leader>mQc",
      desc = "Convert blockquote to callout",
    },
    {
      plug = keymap_helper.plug_name("ConvertToBlockquote"),
      fn = M.convert_to_blockquote,
      modes = { "n" },
      default_key = "<leader>mQb",
      desc = "Convert callout to blockquote",
    },
  })
end

--- Validate callout type
---@param type string Callout type to validate
---@return boolean is_valid True if the type is valid
function M.is_valid_callout_type(type)
  return vim.tbl_contains(M.CALLOUT_TYPES, type)
end

--- Get callout info at cursor position
---@return table|nil callout_info {type: string, start_line: number, end_line: number} or nil if not in callout
function M.get_callout_at_cursor()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]

  -- Find start of callout block (search upward)
  local start_line = nil
  local callout_type = nil

  for line_num = current_line, 1, -1 do
    local line = utils.get_line(line_num)
    local type_match = line:match(CALLOUT_START)

    if type_match then
      start_line = line_num
      callout_type = type_match
      break
    elseif not line:match("^%s*>") then
      -- Not a blockquote line, stop searching
      return nil
    end
  end

  if not start_line or not callout_type then
    return nil
  end

  -- Find end of callout block (search downward)
  local end_line = start_line
  local total_lines = vim.api.nvim_buf_line_count(0)

  for line_num = start_line + 1, total_lines do
    local line = utils.get_line(line_num)
    if line:match("^%s*>") then
      end_line = line_num
    else
      break
    end
  end

  return {
    type = callout_type,
    start_line = start_line,
    end_line = end_line,
  }
end

--- Get default callout type from config
---@return string default_type
function M.get_default_type()
  if M.config.callouts and M.config.callouts.default_type then
    return M.config.callouts.default_type
  end
  return "NOTE"
end

--- Prompt user to select callout type
---@return string|nil selected_type Selected type or nil if cancelled
function M.prompt_for_type()
  vim.ui.select(M.CALLOUT_TYPES, {
    prompt = "Select callout type:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      return choice
    end
  end)

  -- Since vim.ui.select is async, we need to handle it differently
  -- For now, return the default and let the caller use vim.ui.select
  return nil
end

--- Insert callout with specified type (normal mode)
---@param type? string Callout type (prompts if not provided)
---@return nil
function M.insert_callout(type)
  if not type then
    type = M.get_default_type()
  end

  if not M.is_valid_callout_type(type) then
    vim.notify("Invalid callout type: " .. type, vim.log.levels.ERROR)
    return
  end

  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)

  if line == "" then
    -- Insert callout on empty line
    utils.set_line(line_num, string.format("> [!%s]", type))
    vim.api.nvim_buf_set_lines(0, line_num, line_num, false, { "> " })
    vim.api.nvim_win_set_cursor(0, { line_num + 1, 2 })
    vim.cmd("startinsert!")
  else
    -- Insert callout above current line
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num - 1, false, {
      string.format("> [!%s]", type),
      "> ",
    })
    vim.api.nvim_win_set_cursor(0, { line_num, 2 })
    vim.cmd("startinsert!")
  end
end

--- Insert callout with type selection prompt (normal mode)
---@return nil
function M.insert_callout_prompt()
  vim.ui.select(M.CALLOUT_TYPES, {
    prompt = "Select callout type:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      M.insert_callout(choice)
    end
  end)
end

--- Wrap visual selection in callout
---@return nil
function M.wrap_selection_in_callout()
  vim.ui.select(M.CALLOUT_TYPES, {
    prompt = "Select callout type:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    local selection = utils.get_visual_selection(false)
    local start_row = selection.start_row
    local end_row = selection.end_row

    -- Get selected lines
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

    -- Process lines: add > prefix if not present
    local new_lines = {}
    for i, line in ipairs(lines) do
      if i == 1 then
        -- First line gets the callout marker
        if line:match("^%s*>") then
          -- Already has >, replace with callout marker
          line = line:gsub("^%s*>%s?", string.format("> [!%s] ", choice), 1)
        else
          -- Add callout marker
          if line == "" then
            line = string.format("> [!%s]", choice)
          else
            line = string.format("> [!%s] %s", choice, line)
          end
        end
      else
        -- Subsequent lines: ensure > prefix
        if not line:match("^%s*>") then
          if line == "" then
            line = ">"
          else
            line = "> " .. line
          end
        end
      end
      table.insert(new_lines, line)
    end

    -- Replace lines
    vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)
  end)
end

--- Toggle callout type (cycle through types)
---@return nil
function M.toggle_callout_type()
  local callout_info = M.get_callout_at_cursor()

  if not callout_info then
    vim.notify("Not in a callout block", vim.log.levels.WARN)
    return
  end

  -- Find next type in cycle
  local current_idx = 1
  for i, type in ipairs(M.CALLOUT_TYPES) do
    if type == callout_info.type then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #M.CALLOUT_TYPES) + 1
  local next_type = M.CALLOUT_TYPES[next_idx]

  -- Update first line with new type
  local first_line = utils.get_line(callout_info.start_line)
  local new_line = first_line:gsub("%[![A-Z]+%]", string.format("[!%s]", next_type))
  utils.set_line(callout_info.start_line, new_line)

  vim.notify(string.format("Callout type changed: %s → %s", callout_info.type, next_type), vim.log.levels.INFO)
end

--- Convert blockquote to callout
---@return nil
function M.convert_to_callout()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]

  -- Check if already in a callout
  local callout_info = M.get_callout_at_cursor()
  if callout_info then
    vim.notify("Already in a callout block", vim.log.levels.WARN)
    return
  end

  -- Find blockquote boundaries
  local line = utils.get_line(current_line)
  if not line:match("^%s*>") then
    vim.notify("Not in a blockquote", vim.log.levels.WARN)
    return
  end

  -- Find start of blockquote
  local start_line = current_line
  for line_num = current_line - 1, 1, -1 do
    local l = utils.get_line(line_num)
    if l:match("^%s*>") then
      start_line = line_num
    else
      break
    end
  end

  -- Prompt for callout type
  vim.ui.select(M.CALLOUT_TYPES, {
    prompt = "Select callout type:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    -- Update first line to add callout marker
    local first_line = utils.get_line(start_line)
    local content = first_line:match(BLOCKQUOTE_LINE)

    local new_line
    if content == "" then
      new_line = first_line:gsub("^(%s*>%s?)", string.format("%%1[!%s]", choice), 1)
    else
      new_line = first_line:gsub("^(%s*>%s?)", string.format("%%1[!%s] ", choice), 1)
    end

    utils.set_line(start_line, new_line)
    vim.notify(string.format("Converted to %s callout", choice), vim.log.levels.INFO)
  end)
end

--- Convert callout to blockquote
---@return nil
function M.convert_to_blockquote()
  local callout_info = M.get_callout_at_cursor()

  if not callout_info then
    vim.notify("Not in a callout block", vim.log.levels.WARN)
    return
  end

  -- Remove [!TYPE] marker from first line
  local first_line = utils.get_line(callout_info.start_line)
  local new_line = first_line:gsub("%s*%[![A-Z]+%]%s?", " ", 1)
  -- Clean up extra spaces
  new_line = new_line:gsub("^(%s*>)%s+$", "%1", 1)

  utils.set_line(callout_info.start_line, new_line)
  vim.notify("Converted callout to blockquote", vim.log.levels.INFO)
end

return M
