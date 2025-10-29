-- Headers & TOC module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Header pattern (matches # through ######)
M.header_pattern = "^(#+)%s+(.+)$"

---Setup headers module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable headers features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for headers
---@return nil
function M.setup_keymaps()
  local keymaps = {
    {
      plug = keymap_helper.plug_name("NextHeader"),
      fn = M.next_header,
      modes = "n",
      default_key = "]]",
      desc = "Jump to next header",
    },
    {
      plug = keymap_helper.plug_name("PrevHeader"),
      fn = M.prev_header,
      modes = "n",
      default_key = "[[",
      desc = "Jump to previous header",
    },
    {
      plug = keymap_helper.plug_name("PromoteHeader"),
      fn = M.promote_header,
      modes = "n",
      default_key = "<leader>h+",
      desc = "Promote header (increase level)",
    },
    {
      plug = keymap_helper.plug_name("DemoteHeader"),
      fn = M.demote_header,
      modes = "n",
      default_key = "<leader>h-",
      desc = "Demote header (decrease level)",
    },
    {
      plug = keymap_helper.plug_name("GenerateTOC"),
      fn = M.generate_toc,
      modes = "n",
      default_key = "<leader>ht",
      desc = "Generate table of contents",
    },
    {
      plug = keymap_helper.plug_name("UpdateTOC"),
      fn = M.update_toc,
      modes = "n",
      default_key = "<leader>hu",
      desc = "Update table of contents",
    },
    {
      plug = keymap_helper.plug_name("FollowLink"),
      fn = M.follow_link,
      modes = "n",
      default_key = "gd",
      desc = "Follow TOC link to header",
    },
    {
      plug = keymap_helper.plug_name("OpenTocWindow"),
      fn = function()
        M.open_toc_window("vertical")
      end,
      modes = "n",
      default_key = "<leader>hT",
      desc = "Open navigable TOC window",
    },
  }

  -- Add header level shortcuts (h1-h6)
  for i = 1, 6 do
    table.insert(keymaps, {
      plug = keymap_helper.plug_name("Header" .. i),
      fn = function()
        M.set_header_level(i)
      end,
      modes = "n",
      default_key = "<leader>h" .. i,
      desc = "Set/convert to H" .. i,
    })
  end

  keymap_helper.setup_keymaps(M.config, keymaps)

  -- User commands for TOC window
  vim.api.nvim_buf_create_user_command(0, "Toc", function()
    M.open_toc_window("vertical")
  end, { desc = "Open TOC in vertical window" })

  vim.api.nvim_buf_create_user_command(0, "Toch", function()
    M.open_toc_window("horizontal")
  end, { desc = "Open TOC in horizontal window" })

  vim.api.nvim_buf_create_user_command(0, "Toct", function()
    M.open_toc_window("tab")
  end, { desc = "Open TOC in new tab" })
end

-- Parse a line to check if it's a header
function M.parse_header(line)
  if not line then
    return nil
  end

  local hashes, text = line:match(M.header_pattern)
  if hashes and text then
    return {
      level = #hashes,
      text = text,
      hashes = hashes,
    }
  end

  return nil
end

-- Get all headers in the buffer
function M.get_all_headers()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local headers = {}
  local in_code_block = false

  for i, line in ipairs(lines) do
    -- Check for code fence (``` or ~~~)
    if line:match("^```") or line:match("^~~~") then
      in_code_block = not in_code_block
    end

    -- Only parse headers if we're not inside a code block
    if not in_code_block then
      local header = M.parse_header(line)
      if header then
        header.line_num = i
        header.full_line = line
        table.insert(headers, header)
      end
    end
  end

  return headers
end

-- Navigate to next header
function M.next_header()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]
  local headers = M.get_all_headers()

  -- Find next header after current line
  for _, header in ipairs(headers) do
    if header.line_num > current_line then
      utils.set_cursor(header.line_num, 0)
      return
    end
  end

  -- No next header, stay at current position
  print("No next header")
end

-- Navigate to previous header
function M.prev_header()
  local cursor = utils.get_cursor()
  local current_line = cursor[1]
  local headers = M.get_all_headers()

  -- Find previous header before current line (search backwards)
  for i = #headers, 1, -1 do
    local header = headers[i]
    if header.line_num < current_line then
      utils.set_cursor(header.line_num, 0)
      return
    end
  end

  -- No previous header, stay at current position
  print("No previous header")
end

-- Follow link in TOC (jump to header from markdown link)
function M.follow_link()
  local line = utils.get_current_line()

  -- Try to extract anchor from markdown link: [text](#anchor)
  local anchor = line:match("%[.-%]%(#(.-)%)")

  if not anchor then
    -- Not on a TOC link, don't do anything (let other mappings or default behavior handle it)
    return false
  end

  -- Convert anchor back to header text (reverse of slug generation)
  -- Anchors are lowercase with hyphens, need to find matching header
  local headers = M.get_all_headers()

  for _, header in ipairs(headers) do
    local slug = M.generate_slug(header.text)
    if slug == anchor then
      -- Found the matching header, jump to it
      utils.set_cursor(header.line_num, 0)
      -- Center the screen on the header
      vim.cmd("normal! zz")
      return true
    end
  end

  -- No matching header found
  print("Header not found: " .. anchor)
  return false
end

-- Promote header (decrease level number, increase importance)
function M.promote_header()
  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = M.parse_header(line)

  if not header then
    print("Not on a header line")
    return
  end

  if header.level <= 1 then
    print("Already at highest level (H1)")
    return
  end

  -- Decrease level (remove one #)
  local new_level = header.level - 1
  local new_line = string.rep("#", new_level) .. " " .. header.text
  utils.set_line(line_num, new_line)

  print("Promoted to H" .. new_level)
end

-- Demote header (increase level number, decrease importance)
function M.demote_header()
  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = M.parse_header(line)

  if not header then
    print("Not on a header line")
    return
  end

  if header.level >= 6 then
    print("Already at lowest level (H6)")
    return
  end

  -- Increase level (add one #)
  local new_level = header.level + 1
  local new_line = string.rep("#", new_level) .. " " .. header.text
  utils.set_line(line_num, new_line)

  print("Demoted to H" .. new_level)
end

-- Set specific header level
function M.set_header_level(level)
  if level < 1 or level > 6 then
    print("Invalid header level: " .. level)
    return
  end

  local cursor = utils.get_cursor()
  local line_num = cursor[1]
  local line = utils.get_line(line_num)
  local header = M.parse_header(line)

  if header then
    -- Already a header, change its level
    local new_line = string.rep("#", level) .. " " .. header.text
    utils.set_line(line_num, new_line)
    print("Changed to H" .. level)
  else
    -- Not a header, convert current line to header
    local text = line:match("^%s*(.-)%s*$") -- trim whitespace
    if text == "" then
      print("Cannot create header from empty line")
      return
    end
    local new_line = string.rep("#", level) .. " " .. text
    utils.set_line(line_num, new_line)
    print("Created H" .. level)
  end
end

-- Generate a slug from header text (for TOC links)
function M.generate_slug(text)
  local slug = text

  -- Step 1: Remove markdown formatting (must be done before lowercase)
  slug = slug:gsub("%*%*(.-)%*%*", "%1") -- **bold**
  slug = slug:gsub("%*(.-)%*", "%1") -- *italic*
  slug = slug:gsub("`(.-)`", "%1") -- `code`
  slug = slug:gsub("~~(.-)~~", "%1") -- ~~strikethrough~~

  -- Step 2: Convert to lowercase
  slug = slug:lower()

  -- Step 3: Replace spaces with hyphens (before removing punctuation!)
  slug = slug:gsub("%s+", "-")

  -- Step 4: Remove punctuation (GitHub-compatible)
  -- Keep: alphanumeric, hyphens (-), underscores (_)
  -- Remove: & ! @ # $ % ^ * ( ) = + [ ] { } \ | ; : ' " < > ? / . ,
  slug = slug:gsub("[&!@#$%%^*()=+%[%]{}\\|;:'\",<>?/.]", "")

  -- Step 5: Remove leading/trailing hyphens
  slug = slug:gsub("^%-+", "")
  slug = slug:gsub("%-+$", "")

  return slug
end

-- Generate table of contents
function M.generate_toc()
  local headers = M.get_all_headers()

  if #headers == 0 then
    print("No headers found in document")
    return
  end

  -- Check if TOC already exists
  local existing_toc = M.find_toc()
  if existing_toc then
    print("TOC already exists. Use <leader>hu to update it.")
    return
  end

  -- Find where to insert TOC (right before first non-H1 header)
  local toc_insert_line = 1

  -- Find first header that is not H1
  for _, header in ipairs(headers) do
    if header.level > 1 then
      -- Insert right before this header (but at least at line 1)
      toc_insert_line = math.max(1, header.line_num - 1)
      break
    end
  end

  -- If all headers are H1 (unusual), default to after first H1
  if toc_insert_line == 1 and headers[1] and headers[1].level == 1 then
    toc_insert_line = headers[1].line_num + 1
  end

  -- Build TOC lines with HTML comment markers
  local toc_lines = {
    "",
    "<!-- TOC -->",
    "",
    "## Table of Contents",
    "",
  }

  for _, header in ipairs(headers) do
    -- Skip H1 (usually the document title)
    if header.level > 1 then
      local indent = string.rep("  ", header.level - 2)
      local slug = M.generate_slug(header.text)
      local toc_line = indent .. "- [" .. header.text .. "](#" .. slug .. ")"
      table.insert(toc_lines, toc_line)
    end
  end

  table.insert(toc_lines, "")
  table.insert(toc_lines, "<!-- /TOC -->")
  table.insert(toc_lines, "")

  -- Insert TOC into buffer
  vim.api.nvim_buf_set_lines(0, toc_insert_line - 1, toc_insert_line - 1, false, toc_lines)

  print("TOC generated with " .. (#headers - 1) .. " entries")
end

---Check if content between markers looks like a valid TOC
---@param lines string[] All lines in buffer
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean is_valid True if content looks like a TOC
---@param lines string[]
---@param start_line number
---@param end_line number
---@return boolean
local function is_valid_toc_content(lines, start_line, end_line)
  local has_toc_header = false
  local has_links = false
  local link_count = 0

  for i = start_line, end_line do
    local line = lines[i]
    if not line then
      break
    end

    -- Check for TOC header
    if line:match("^##%s+[Tt]able%s+[Oo]f%s+[Cc]ontents") then
      has_toc_header = true
    end

    -- Check for markdown links (TOC entries)
    -- Match patterns like: - [Text](#link) or   - [Text](#link)
    if line:match("^%s*%-%s+%[.-%]%(#.-%)") then
      has_links = true
      link_count = link_count + 1
    end
  end

  -- Valid TOC should have either:
  -- 1. A TOC header + at least one link, OR
  -- 2. At least 1 link (for TOCs without header)
  return (has_toc_header and has_links) or (link_count >= 1)
end

---Find existing TOC in document
---@return {start_line: number, end_line: number}|nil TOC location
function M.find_toc()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Look for <!-- TOC --> marker pairs
  local toc_candidates = {}

  for i, line in ipairs(lines) do
    if line:match("^%s*<!%-%-%s*TOC%s*%-%->%s*$") then
      -- Found opening marker, look for closing marker
      for j = i + 1, #lines do
        if lines[j]:match("^%s*<!%-%-%s*/TOC%s*%-%->%s*$") then
          -- Found a complete pair, validate it's actually a TOC
          if is_valid_toc_content(lines, i, j) then
            table.insert(toc_candidates, {
              start_line = i,
              end_line = j,
            })
          end
          break
        end
      end
    end
  end

  -- Return the first valid TOC found
  if #toc_candidates > 0 then
    return toc_candidates[1]
  end

  -- Fallback: look for old-style TOC without markers (for backwards compatibility)
  for i, line in ipairs(lines) do
    -- Look for "## Table of Contents" or similar
    if line:match("^##%s+[Tt]able%s+[Oo]f%s+[Cc]ontents") then
      -- Check if the next few lines contain TOC links
      local has_links = false
      local check_lines = math.min(i + 10, #lines) -- Check next 10 lines

      for j = i + 1, check_lines do
        if lines[j]:match("^%s*%-%s+%[.-%]%(#.-%)") then
          has_links = true
          break
        end
      end

      -- Only treat as TOC if it has actual links
      if has_links then
        -- Find the end of TOC (next header at same or higher level)
        local toc_end_line = i
        for j = i + 1, #lines do
          local next_line = lines[j]
          -- TOC ends at next header (any level: #, ##, ###, etc.)
          -- Pattern matches lines starting with # followed by space
          if next_line:match("^#+%s") then
            toc_end_line = j - 1
            break
          end
          -- Also end at blank line followed by non-list content
          if next_line == "" and lines[j + 1] and not lines[j + 1]:match("^%s*%-") then
            toc_end_line = j - 1
            break
          end
          toc_end_line = j
        end

        return {
          start_line = i,
          end_line = toc_end_line,
        }
      end
    end
  end

  return nil
end

-- Update existing TOC
function M.update_toc()
  local toc_location = M.find_toc()

  if not toc_location then
    print("No TOC found. Use <leader>ht to generate one.")
    return
  end

  local headers = M.get_all_headers()

  -- Build new TOC content with markers
  local toc_lines = {
    "<!-- TOC -->",
    "",
    "## Table of Contents",
    "",
  }

  for _, header in ipairs(headers) do
    -- Skip H1 and skip if header is within TOC range
    if header.level > 1 and (header.line_num < toc_location.start_line or header.line_num > toc_location.end_line) then
      local indent = string.rep("  ", header.level - 2)
      local slug = M.generate_slug(header.text)
      local toc_line = indent .. "- [" .. header.text .. "](#" .. slug .. ")"
      table.insert(toc_lines, toc_line)
    end
  end

  table.insert(toc_lines, "")
  table.insert(toc_lines, "<!-- /TOC -->")

  -- Replace old TOC with new one
  vim.api.nvim_buf_set_lines(0, toc_location.start_line - 1, toc_location.end_line, false, toc_lines)

  print("TOC updated")
end

-- Constants for TOC window
local TOC_WINDOW_PADDING = 5 -- Extra padding for window width calculation
local TOC_MAX_WIDTH_RATIO = 0.5 -- Maximum width as ratio of screen width
local TOC_DEFAULT_MAX_DEPTH = 2 -- Default initial depth to show

-- State for TOC window
local toc_state = {
  source_bufnr = nil,
  toc_bufnr = nil,
  toc_winnr = nil,
  headers = {},
  expanded_levels = {}, -- Track which headers are expanded
  visible_headers = {}, -- Currently visible headers
  max_depth = TOC_DEFAULT_MAX_DEPTH, -- Initial depth to show
}

--- Check if a header's children should be visible
---@param header_idx number Index of the header in headers array
---@return boolean
local function is_expanded(header_idx)
  return toc_state.expanded_levels[header_idx] == true
end

--- Get children of a header
---@param header_idx number Index of the parent header
---@return table List of child header indices
local function get_children(header_idx)
  local children = {}
  local parent_level = toc_state.headers[header_idx].level

  for i = header_idx + 1, #toc_state.headers do
    local header = toc_state.headers[i]
    if header.level <= parent_level then
      break -- No more children
    end
    if header.level == parent_level + 1 then
      table.insert(children, i)
    end
  end

  return children
end

--- Build the visible headers list based on expansion state
local function build_visible_headers()
  toc_state.visible_headers = {}

  for i, header in ipairs(toc_state.headers) do
    -- Check if this header should be visible
    local should_show = false

    if header.level <= toc_state.max_depth then
      -- Within initial depth
      should_show = true
    else
      -- Check if any parent is expanded
      local parent_idx = nil
      for j = i - 1, 1, -1 do
        if toc_state.headers[j].level < header.level then
          parent_idx = j
          break
        end
      end

      if parent_idx and is_expanded(parent_idx) then
        -- Direct parent is expanded, check if we should show this level
        should_show = header.level <= toc_state.headers[parent_idx].level + 1
      end
    end

    if should_show then
      table.insert(toc_state.visible_headers, {
        idx = i,
        header = header,
        has_children = #get_children(i) > 0,
        is_expanded = is_expanded(i),
      })
    end
  end
end

--- Format a header line for display
---@param visible_header table The visible header entry
---@return string
local function format_header_line(visible_header)
  local header = visible_header.header
  local indent = string.rep("  ", header.level - 1)

  local fold_marker
  if visible_header.has_children then
    fold_marker = visible_header.is_expanded and "▼ " or "▶ "
  else
    fold_marker = "  "
  end

  -- Format: [H1] Title (max level is 6, so no padding needed)
  local level_indicator = string.format("[H%d] ", header.level)

  return indent .. fold_marker .. level_indicator .. header.text
end

--- Render the TOC buffer
local function render_toc()
  if not toc_state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.toc_bufnr) then
    return
  end

  build_visible_headers()

  local lines = {}
  local max_len = 0

  for _, visible_header in ipairs(toc_state.visible_headers) do
    local line = format_header_line(visible_header)
    table.insert(lines, line)

    local line_len = vim.fn.strdisplaywidth(line)
    if line_len > max_len then
      max_len = line_len
    end
  end

  vim.bo[toc_state.toc_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(toc_state.toc_bufnr, 0, -1, false, lines)
  vim.bo[toc_state.toc_bufnr].modifiable = false
  vim.bo[toc_state.toc_bufnr].modified = false

  -- Auto-resize window
  if toc_state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.toc_winnr) then
    local win_width = math.min(max_len + TOC_WINDOW_PADDING, math.floor(vim.o.columns * TOC_MAX_WIDTH_RATIO))
    vim.api.nvim_win_set_width(toc_state.toc_winnr, win_width)
  end
end

--- Expand a header to show its children
local function expand_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]
  if not visible_header.has_children then
    return
  end

  -- Mark as expanded
  toc_state.expanded_levels[visible_header.idx] = true

  -- Re-render
  render_toc()
end

--- Collapse a header to hide its children
local function collapse_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]

  -- If already collapsed or expanded, collapse it
  if visible_header.is_expanded then
    toc_state.expanded_levels[visible_header.idx] = false
    render_toc()
    return
  end

  -- Otherwise, find parent and collapse it
  local header_idx = visible_header.idx
  local current_level = visible_header.header.level

  -- Find parent
  for i = header_idx - 1, 1, -1 do
    if toc_state.headers[i].level < current_level then
      -- Found parent, collapse it
      toc_state.expanded_levels[i] = false

      -- Find the parent's line in visible headers and move cursor there
      for j, vh in ipairs(toc_state.visible_headers) do
        if vh.idx == i then
          render_toc()
          vim.api.nvim_win_set_cursor(0, { j, 0 })
          return
        end
      end

      render_toc()
      return
    end
  end
end

--- Jump to the header in the source buffer
local function jump_to_header()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  if line > #toc_state.visible_headers then
    return
  end

  local visible_header = toc_state.visible_headers[line]
  local header = visible_header.header

  -- Find the window containing the source buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == toc_state.source_bufnr then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { header.line_num, 0 })
      vim.cmd("normal! zz") -- Center the line
      return
    end
  end
end

--- Show help popup for TOC window keybindings
local function show_toc_help()
  local help_lines = {
    "╔═══════════════════════════════════════╗",
    "║       TOC Navigation Help             ║",
    "╠═══════════════════════════════════════╣",
    "║                                       ║",
    "║  Movement:                            ║",
    "║    j/k       - Move cursor up/down    ║",
    "║    <Up/Down> - Move cursor up/down    ║",
    "║                                       ║",
    "║  Folding:                             ║",
    "║    l         - Expand header          ║",
    "║    h         - Collapse or go parent  ║",
    "║                                       ║",
    "║  Actions:                             ║",
    "║    <Enter>   - Jump to header         ║",
    "║    q         - Close TOC window       ║",
    "║    ?         - Toggle this help       ║",
    "║                                       ║",
    "║  Visual Indicators:                   ║",
    "║    ▶         - Collapsed (has child)  ║",
    "║    ▼         - Expanded (showing)     ║",
    "║    [H1]      - Header level           ║",
    "║                                       ║",
    "╚═══════════════════════════════════════╝",
  }

  -- Calculate popup dimensions
  local width = 43
  local height = #help_lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer for help
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
  })

  -- Set window options
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"

  -- Close on any key press
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "?", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

--- Set up keymaps for the TOC buffer
local function setup_toc_keymaps()
  local opts = { buffer = toc_state.toc_bufnr, silent = true, nowait = true }

  vim.keymap.set("n", "l", expand_header, vim.tbl_extend("force", opts, { desc = "Expand header" }))
  vim.keymap.set("n", "h", collapse_header, vim.tbl_extend("force", opts, { desc = "Collapse header" }))
  vim.keymap.set("n", "<CR>", jump_to_header, vim.tbl_extend("force", opts, { desc = "Jump to header" }))
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, vim.tbl_extend("force", opts, { desc = "Close TOC" }))
  vim.keymap.set("n", "?", show_toc_help, vim.tbl_extend("force", opts, { desc = "Show help" }))
end

--- Check if TOC window is currently open
---@return boolean
local function is_toc_open()
  if toc_state.toc_winnr and vim.api.nvim_win_is_valid(toc_state.toc_winnr) then
    return true
  end
  return false
end

--- Close the TOC window if it's open
---@return boolean True if window was closed
local function close_toc_window()
  if is_toc_open() then
    vim.api.nvim_win_close(toc_state.toc_winnr, true)
    toc_state.toc_winnr = nil
    return true
  end
  return false
end

--- Get the TOC statusline string
---@return string
local function get_toc_statusline()
  return "%#StatusLine# TOC %#StatusLineNC#│ l=expand  h=collapse  ⏎=jump  q=close  ?=help"
end

--- Set up syntax highlighting for TOC buffer
local function setup_toc_highlights()
  -- Define highlight groups (global)
  vim.cmd([[
    highlight default link TocLevel Comment
    highlight default link TocMarkerClosed Special
    highlight default link TocMarkerOpen Special
    highlight default link TocH1 Title
    highlight default link TocH2 Function
    highlight default link TocH3 String
    highlight default link TocH4 Type
    highlight default link TocH5 Identifier
    highlight default link TocH6 Constant
  ]])

  -- Set up syntax matches in the TOC buffer context
  vim.api.nvim_buf_call(toc_state.toc_bufnr, function()
    -- Enable syntax
    vim.cmd("syntax enable")
    vim.cmd("syntax clear")

    -- Match markers first (so they can be contained)
    vim.cmd([[syntax match TocMarkerClosed "▶" contained]])
    vim.cmd([[syntax match TocMarkerOpen "▼" contained]])
    vim.cmd([[syntax match TocLevel "\[H[1-6]\]" contained]])

    -- Match full lines by header level
    -- Use consistent pattern for all levels to handle whitespace/markers
    vim.cmd([[syntax match TocH1 "^.*\[H1\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH2 "^.*\[H2\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH3 "^.*\[H3\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH4 "^.*\[H4\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH5 "^.*\[H5\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
    vim.cmd([[syntax match TocH6 "^.*\[H6\].*$" contains=TocLevel,TocMarkerClosed,TocMarkerOpen]])
  end)
end

--- Open a navigable TOC in a custom buffer window
---@param window_type? string Window type: 'vertical', 'horizontal', or 'tab' (default: 'vertical')
---@return nil
function M.open_toc_window(window_type)
  window_type = window_type or "vertical"

  -- Toggle: if already open, close it
  if is_toc_open() then
    close_toc_window()
    return
  end

  -- Get all headers
  local headers = M.get_all_headers()

  if #headers == 0 then
    vim.notify("TOC: No headers found", vim.log.levels.WARN)
    return
  end

  -- Capture cursor position in source buffer before switching windows
  local source_cursor_line = vim.fn.line(".")

  -- Store state
  toc_state.source_bufnr = vim.api.nvim_get_current_buf()
  toc_state.headers = headers
  toc_state.expanded_levels = {}
  toc_state.visible_headers = {}
  toc_state.max_depth = M.config.toc and M.config.toc.initial_depth or TOC_DEFAULT_MAX_DEPTH

  -- Create or reuse TOC buffer
  if not toc_state.toc_bufnr or not vim.api.nvim_buf_is_valid(toc_state.toc_bufnr) then
    toc_state.toc_bufnr = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    vim.bo[toc_state.toc_bufnr].buftype = "nofile"
    vim.bo[toc_state.toc_bufnr].bufhidden = "hide"
    vim.bo[toc_state.toc_bufnr].swapfile = false
    vim.bo[toc_state.toc_bufnr].modifiable = false
    vim.bo[toc_state.toc_bufnr].filetype = "markdown-toc"

    -- Set buffer name
    vim.api.nvim_buf_set_name(
      toc_state.toc_bufnr,
      "TOC: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(toc_state.source_bufnr), ":t")
    )
  end

  -- Open window
  if window_type == "horizontal" then
    vim.cmd("split")
  elseif window_type == "vertical" then
    vim.cmd("vsplit")
  elseif window_type == "tab" then
    vim.cmd("tabnew")
  end

  toc_state.toc_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(toc_state.toc_winnr, toc_state.toc_bufnr)

  -- Set window options
  vim.wo[toc_state.toc_winnr].number = false
  vim.wo[toc_state.toc_winnr].relativenumber = false
  vim.wo[toc_state.toc_winnr].cursorline = true
  vim.wo[toc_state.toc_winnr].wrap = false
  vim.wo[toc_state.toc_winnr].signcolumn = "no"
  vim.wo[toc_state.toc_winnr].foldcolumn = "0"
  vim.wo[toc_state.toc_winnr].colorcolumn = ""

  -- Set a helpful status line
  vim.wo[toc_state.toc_winnr].statusline = get_toc_statusline()

  -- Set up syntax highlighting
  setup_toc_highlights()

  -- Set up keymaps
  setup_toc_keymaps()

  -- Initial render
  render_toc()

  -- Position cursor at header closest to source buffer cursor position
  local closest_idx = 1

  for i, header in ipairs(headers) do
    if header.line_num <= source_cursor_line then
      closest_idx = i
    else
      break
    end
  end

  -- Find the visible header index
  for i, visible_header in ipairs(toc_state.visible_headers) do
    if visible_header.idx == closest_idx then
      vim.api.nvim_win_set_cursor(toc_state.toc_winnr, { i, 0 })
      break
    end
  end
end

return M
