-- Links & References module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Link patterns for detection
---@type table<string, string>
M.patterns = {
  inline_link = "%[(.-)%]%((.-)%)", -- [text](url)
  reference_link = "%[(.-)%]%[(.-)%]", -- [text][ref]
  reference_def = "^%[(.-)%]:%s*(.+)$", -- [ref]: url
  url = "https?://[%w-_%.%?%.:/%#%[%]@!%$&'%(%)%*%+,;=]+", -- URL pattern
}

---Setup links module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable links features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for links
---@return nil
function M.setup_keymaps()
  -- Insert link
  vim.keymap.set("n", "<leader>ml", M.insert_link, {
    buffer = true,
    silent = true,
    desc = "Insert markdown link",
  })

  -- Convert selection to link
  vim.keymap.set("v", "<leader>ml", M.selection_to_link, {
    buffer = true,
    silent = true,
    desc = "Convert selection to link",
  })

  -- Edit link under cursor
  vim.keymap.set("n", "<leader>me", M.edit_link, {
    buffer = true,
    silent = true,
    desc = "Edit link under cursor",
  })

  -- Convert to reference-style link
  vim.keymap.set("n", "<leader>mR", M.convert_to_reference, {
    buffer = true,
    silent = true,
    desc = "Convert to reference-style link",
  })

  -- Convert to inline link
  vim.keymap.set("n", "<leader>mI", M.convert_to_inline, {
    buffer = true,
    silent = true,
    desc = "Convert to inline link",
  })

  -- Auto-convert URL to link
  vim.keymap.set("n", "<leader>ma", M.auto_link_url, {
    buffer = true,
    silent = true,
    desc = "Convert URL to markdown link",
  })
end

-- Parse link under cursor
function M.get_link_at_cursor()
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2] -- 0-indexed column

  -- Find all inline links [text](url) with their positions
  local init = 1
  while true do
    local link_start, link_end = line:find("%[.-%]%(.-%)", init)
    if not link_start then
      break
    end

    -- Check if cursor is within this link
    local start_idx = link_start - 1
    local end_idx = link_end - 1

    if col >= start_idx and col <= end_idx then
      -- Extract text and url from the matched link
      local link_str = line:sub(link_start, link_end)
      local text, url = link_str:match("^%[(.-)%]%((.-)%)$")

      if text and url then
        return {
          type = "inline",
          text = text,
          url = url,
          start_pos = link_start,
          end_pos = link_end,
          line_num = cursor[1],
        }
      end
    end

    init = link_end + 1
  end

  -- Find all reference links [text][ref] with their positions
  init = 1
  while true do
    local link_start, link_end = line:find("%[.-%]%[.-%]", init)
    if not link_start then
      break
    end

    -- Check if cursor is within this link
    local start_idx = link_start - 1
    local end_idx = link_end - 1

    if col >= start_idx and col <= end_idx then
      -- Extract text and ref from the matched link
      local link_str = line:sub(link_start, link_end)
      local text, ref = link_str:match("^%[(.-)%]%[(.-)%]$")

      if text and ref then
        return {
          type = "reference",
          text = text,
          ref = ref,
          start_pos = link_start,
          end_pos = link_end,
          line_num = cursor[1],
        }
      end
    end

    init = link_end + 1
  end

  return nil
end

-- Insert a new link
function M.insert_link()
  -- Prompt for link text
  local text = vim.fn.input("Link text: ")
  if text == "" then
    return
  end

  -- Prompt for URL
  local url = vim.fn.input("URL: ")
  if url == "" then
    return
  end

  -- Insert link at cursor position
  local link = "[" .. text .. "](" .. url .. ")"
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2]

  local new_line = line:sub(1, col) .. link .. line:sub(col + 1)
  utils.set_line(cursor[1], new_line)

  -- Move cursor after the link
  utils.set_cursor(cursor[1], col + #link)

  print("Link inserted")
end

-- Convert selection to link
function M.selection_to_link()
  -- Exit visual mode first to update marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Only support single line for now
  if start_row ~= end_row then
    print("Multi-line links not supported")
    return
  end

  local line = utils.get_line(start_row)

  -- Extract selected text (vim columns are 1-indexed)
  local text = line:sub(start_col, end_col)

  -- Trim any whitespace
  text = text:match("^%s*(.-)%s*$")

  if text == "" then
    print("No text selected")
    return
  end

  -- Prompt for URL
  local url = vim.fn.input("URL: ")
  if url == "" then
    return
  end

  -- Replace selection with link
  local link = "[" .. text .. "](" .. url .. ")"
  local new_line = line:sub(1, start_col - 1) .. link .. line:sub(end_col + 1)
  utils.set_line(start_row, new_line)

  -- Move cursor to after the link
  utils.set_cursor(start_row, start_col - 1 + #link)

  print("Link created")
end

-- Edit link under cursor
function M.edit_link()
  local link = M.get_link_at_cursor()

  if not link then
    print("No link under cursor")
    return
  end

  if link.type == "inline" then
    -- Edit inline link
    local new_text = vim.fn.input("Link text: ", link.text)
    if new_text == "" then
      return
    end

    local new_url = vim.fn.input("URL: ", link.url)
    if new_url == "" then
      return
    end

    -- Replace link
    local line = utils.get_line(link.line_num)
    local new_link = "[" .. new_text .. "](" .. new_url .. ")"
    local new_line = line:sub(1, link.start_pos - 1) .. new_link .. line:sub(link.end_pos + 1)
    utils.set_line(link.line_num, new_line)

    print("Link updated")
  elseif link.type == "reference" then
    -- Edit reference link
    local new_text = vim.fn.input("Link text: ", link.text)
    if new_text == "" then
      return
    end

    local new_ref = vim.fn.input("Reference: ", link.ref)
    if new_ref == "" then
      return
    end

    -- Replace link
    local line = utils.get_line(link.line_num)
    local new_link = "[" .. new_text .. "][" .. new_ref .. "]"
    local new_line = line:sub(1, link.start_pos - 1) .. new_link .. line:sub(link.end_pos + 1)
    utils.set_line(link.line_num, new_line)

    print("Reference link updated")
  end
end

-- Find reference URL definition
function M.find_reference_url(ref)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for _, line in ipairs(lines) do
    local found_ref, url = line:match(M.patterns.reference_def)
    if found_ref and found_ref == ref then
      return url:match("^%s*(.-)%s*$") -- trim whitespace
    end
  end

  return nil
end

-- Convert inline link to reference-style
function M.convert_to_reference()
  local link = M.get_link_at_cursor()

  if not link then
    print("No link under cursor")
    return
  end

  if link.type ~= "inline" then
    print("Not an inline link")
    return
  end

  -- Generate reference ID (use lowercase text as ref)
  local ref = link.text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")

  -- Validate that ref is not empty
  if ref == "" then
    print("Cannot generate reference: link text does not contain any alphanumeric characters")
    return
  end

  -- Check if reference already exists with the same URL
  local existing_url = M.find_reference_url(ref)
  if existing_url and existing_url == link.url then
    -- Use existing reference
    local line = utils.get_line(link.line_num)
    local new_link = "[" .. link.text .. "][" .. ref .. "]"
    local new_line = line:sub(1, link.start_pos - 1) .. new_link .. line:sub(link.end_pos + 1)
    utils.set_line(link.line_num, new_line)
    print("Converted to reference link (existing ref)")
    return
  end

  -- Replace inline link with reference link
  local line = utils.get_line(link.line_num)
  local new_link = "[" .. link.text .. "][" .. ref .. "]"
  local new_line = line:sub(1, link.start_pos - 1) .. new_link .. line:sub(link.end_pos + 1)
  utils.set_line(link.line_num, new_line)

  -- Add reference definition at end of document
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local last_line = #lines

  -- Add blank line if needed
  if lines[last_line] ~= "" then
    vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { "" })
    last_line = last_line + 1
  end

  -- Add reference definition
  local ref_def = "[" .. ref .. "]: " .. link.url
  vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { ref_def })

  print("Converted to reference-style link")
end

-- Convert reference link to inline
function M.convert_to_inline()
  local link = M.get_link_at_cursor()

  if not link then
    print("No link under cursor")
    return
  end

  if link.type ~= "reference" then
    print("Not a reference link")
    return
  end

  -- Find reference URL
  local url = M.find_reference_url(link.ref)
  if not url then
    print("Reference definition not found: " .. link.ref)
    return
  end

  -- Replace reference link with inline link
  local line = utils.get_line(link.line_num)
  local new_link = "[" .. link.text .. "](" .. url .. ")"
  local new_line = line:sub(1, link.start_pos - 1) .. new_link .. line:sub(link.end_pos + 1)
  utils.set_line(link.line_num, new_line)

  print("Converted to inline link")
end

-- Auto-convert URL to link
function M.auto_link_url()
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2] -- 0-indexed column

  -- Find all URLs in the line with their positions
  local urls = {}
  local init = 1
  while true do
    local url_start, url_end, url = line:find("(" .. M.patterns.url .. ")", init)
    if not url_start then
      break
    end
    table.insert(urls, {
      url = url,
      start_pos = url_start,
      end_pos = url_end,
    })
    init = url_end + 1
  end

  -- Find URL under cursor
  for _, url_info in ipairs(urls) do
    -- Convert to 0-indexed for comparison with cursor col
    local start_idx = url_info.start_pos - 1
    local end_idx = url_info.end_pos - 1

    if col >= start_idx and col <= end_idx then
      -- Prompt for link text (default to URL)
      local text = vim.fn.input("Link text (empty for URL): ")
      if text == "" then
        text = url_info.url
      end

      -- Replace URL with link
      local link = "[" .. text .. "](" .. url_info.url .. ")"
      local new_line = line:sub(1, url_info.start_pos - 1) .. link .. line:sub(url_info.end_pos + 1)
      utils.set_line(cursor[1], new_line)

      -- Move cursor to after the link
      utils.set_cursor(cursor[1], url_info.start_pos - 1 + #link)

      print("URL converted to link")
      return
    end
  end

  print("No URL under cursor")
end

return M
