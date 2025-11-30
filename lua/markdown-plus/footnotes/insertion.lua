-- Footnote insertion, editing, and deletion module for markdown-plus.nvim
local parser = require("markdown-plus.footnotes.parser")
local utils = require("markdown-plus.utils")

local M = {}

---@type string Section header for footnotes
local section_header = "Footnotes"

---@type boolean Whether to confirm before deleting
local confirm_delete = true

---Set the section header
---@param header string The header text
function M.set_section_header(header)
  section_header = header or "Footnotes"
end

---Set confirm_delete setting
---@param confirm boolean Whether to confirm before deleting
function M.set_confirm_delete(confirm)
  if confirm == nil then
    confirm_delete = true
  else
    confirm_delete = confirm
  end
end

---Get the section header from config
---@return string section_header
local function get_section_header()
  return section_header
end

---Get confirm_delete setting from config
---@return boolean confirm_delete
local function should_confirm_delete()
  return confirm_delete
end

---Find or create the footnotes section at the end of the document
---@param bufnr? number Buffer number (0 or nil for current)
---@return number line_num Line number where definitions should be added
---@return boolean has_existing_defs Whether there are existing definitions (for spacing)
local function ensure_footnotes_section(bufnr)
  bufnr = bufnr or 0
  local header = get_section_header()

  -- Check if section already exists
  local existing = parser.find_footnotes_section(bufnr, header)
  if existing then
    -- Find the last line of definitions in this section
    local lines = vim.api.nvim_buf_get_lines(bufnr, existing, -1, false)
    local last_def_line = existing
    local has_defs = false

    for i, line in ipairs(lines) do
      local abs_line = existing + i
      local def = parser.parse_definition(line)
      if def then
        has_defs = true
        -- Get full range of this definition (including multi-line)
        local start_line, end_line = parser.get_definition_range(bufnr, abs_line)
        if start_line then
          last_def_line = end_line
        end
      end
    end

    return last_def_line + 1, has_defs
  end

  -- Section doesn't exist - create it at the end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total_lines = #lines

  -- Add blank line if document doesn't end with one
  local new_lines = {}
  if total_lines > 0 and lines[total_lines] ~= "" then
    table.insert(new_lines, "")
  end

  -- Add section header
  table.insert(new_lines, "## " .. header)
  table.insert(new_lines, "")

  vim.api.nvim_buf_set_lines(bufnr, total_lines, total_lines, false, new_lines)

  -- Return line number where definition should go
  return total_lines + #new_lines + 1, false
end

---Insert a new footnote at cursor position
---Prompts user for ID (pre-filled with next numeric), inserts reference and definition
function M.insert_footnote()
  local bufnr = 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  -- Get next available numeric ID
  local next_id = parser.get_next_numeric_id(bufnr)

  -- Prompt user for ID
  vim.ui.input({
    prompt = "Footnote ID: ",
    default = next_id,
  }, function(input)
    if not input or input == "" then
      return -- User cancelled
    end

    local id = input

    -- Validate ID (alphanumeric, hyphen, underscore only)
    if not id:match("^[%w%-_]+$") then
      utils.notify("Invalid footnote ID. Use only letters, numbers, hyphens, and underscores.", vim.log.levels.ERROR)
      return
    end

    -- Check if this ID already exists
    local existing_def = parser.find_definition(bufnr, id)

    -- Insert reference after the character the cursor is on
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
    local reference = "[^" .. id .. "]"

    -- Use UTF-8 safe split to handle multibyte characters correctly
    local before, after = utils.split_after_cursor(line, col)
    local new_line = before .. reference .. after
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

    -- If definition already exists, just insert the reference and notify
    if existing_def then
      -- Move cursor after the inserted reference
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #reference })
      utils.notify(
        "Added reference to existing footnote [^" .. id .. "] (definition at line " .. existing_def.line_num .. ")",
        vim.log.levels.INFO
      )
      return
    end

    -- Ensure footnotes section exists and get insert position
    local def_line, has_existing_defs = ensure_footnotes_section(bufnr)

    -- Add empty line before new definition if there are existing definitions
    if has_existing_defs then
      vim.api.nvim_buf_set_lines(bufnr, def_line - 1, def_line - 1, false, { "" })
      def_line = def_line + 1
    end

    -- Insert definition
    local definition = "[^" .. id .. "]: "
    vim.api.nvim_buf_set_lines(bufnr, def_line - 1, def_line - 1, false, { definition })

    -- Move cursor to definition for content entry
    vim.cmd("normal! m'") -- Save current position to jump list
    vim.api.nvim_win_set_cursor(0, { def_line, #definition })
    vim.cmd("startinsert!")

    utils.notify("Inserted footnote [^" .. id .. "]", vim.log.levels.INFO)
  end)
end

---Edit the footnote definition under cursor
---Works from either reference or definition
function M.edit_footnote()
  local bufnr = 0
  local fn_info = parser.get_footnote_at_cursor(bufnr)

  if not fn_info then
    utils.notify("No footnote under cursor", vim.log.levels.WARN)
    return
  end

  -- Find the definition
  local def = parser.find_definition(bufnr, fn_info.id)
  if not def then
    utils.notify("No definition found for [^" .. fn_info.id .. "]", vim.log.levels.WARN)
    return
  end

  -- Jump to definition and position cursor at end of line, enter insert mode
  local line = vim.api.nvim_buf_get_lines(bufnr, def.line_num - 1, def.line_num, false)[1]
  vim.api.nvim_win_set_cursor(0, { def.line_num, #line })
  vim.cmd("startinsert!")
  utils.notify("Editing footnote [^" .. fn_info.id .. "]", vim.log.levels.INFO)
end

---Delete a footnote (both reference and definition)
---Works from either reference or definition
function M.delete_footnote()
  local bufnr = 0
  local fn_info = parser.get_footnote_at_cursor(bufnr)

  if not fn_info then
    utils.notify("No footnote under cursor", vim.log.levels.WARN)
    return
  end

  local id = fn_info.id

  -- Find all references and definition
  local refs = parser.find_references(bufnr, id)
  local def = parser.find_definition(bufnr, id)

  local ref_count = #refs
  local has_def = def ~= nil

  -- Build confirmation message
  local msg = string.format(
    "Delete footnote [^%s]? (%d reference%s%s)",
    id,
    ref_count,
    ref_count == 1 and "" or "s",
    has_def and ", 1 definition" or ", no definition"
  )

  -- Confirm deletion if configured
  local function do_delete()
    -- Collect definition lines first, then delete references, then definition
    -- Work from bottom to top to avoid line number shifts
    local lines_to_delete = {}

    if def then
      local start_line, end_line = parser.get_definition_range(bufnr, def.line_num)
      if start_line then
        for line_num = end_line, start_line, -1 do
          table.insert(lines_to_delete, { type = "line", line_num = line_num })
        end
      end
    end

    -- Sort references by line number descending, then by column descending
    table.sort(refs, function(a, b)
      if a.line_num == b.line_num then
        return a.start_col > b.start_col
      end
      return a.line_num > b.line_num
    end)

    -- Delete references (in-line replacements)
    for _, ref in ipairs(refs) do
      local line = vim.api.nvim_buf_get_lines(bufnr, ref.line_num - 1, ref.line_num, false)[1]
      local new_line = line:sub(1, ref.start_col - 1) .. line:sub(ref.end_col + 1)
      vim.api.nvim_buf_set_lines(bufnr, ref.line_num - 1, ref.line_num, false, { new_line })
    end

    -- Delete definition lines (sorted from bottom to top already)
    for _, item in ipairs(lines_to_delete) do
      vim.api.nvim_buf_set_lines(bufnr, item.line_num - 1, item.line_num, false, {})
    end

    utils.notify(
      string.format("Deleted footnote [^%s] (%d reference%s)", id, ref_count, ref_count == 1 and "" or "s"),
      vim.log.levels.INFO
    )
  end

  if should_confirm_delete() then
    vim.ui.select({ "Yes", "No" }, {
      prompt = msg,
    }, function(choice)
      if choice == "Yes" then
        do_delete()
      end
    end)
  else
    do_delete()
  end
end

return M
