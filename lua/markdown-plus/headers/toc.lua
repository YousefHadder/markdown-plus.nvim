-- TOC generation and management module for markdown-plus.nvim
local parser = require("markdown-plus.headers.parser")
local M = {}

---Check if content between markers looks like a valid TOC
---@param lines string[] All lines in buffer
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean is_valid True if content looks like a TOC
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
    if line:match("^%s*%-%s+%[.-%]%(#.-%)") then
      has_links = true
      link_count = link_count + 1
    end
  end

  -- Valid TOC should have either a TOC header + links, or at least 1 link
  return (has_toc_header and has_links) or (link_count >= 1)
end

---Find existing TOC in document
---@return {start_line: number, end_line: number}|nil TOC location
function M.find_toc()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Look for <!-- TOC --> marker pairs
  local toc_start = nil

  for i, line in ipairs(lines) do
    if line:match("^%s*<!%-%-%s*TOC%s*%-%->") then
      toc_start = i
    elseif toc_start and line:match("^%s*<!%-%-%s*/TOC%s*%-%->") then
      local toc_end = i

      -- Validate that content between markers looks like a TOC
      if is_valid_toc_content(lines, toc_start, toc_end) then
        return {
          start_line = toc_start,
          end_line = toc_end,
        }
      else
        -- Invalid TOC content, keep searching
        toc_start = nil
      end
    end
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

---Generate table of contents
---@return nil
function M.generate_toc()
  local headers = parser.get_all_headers()

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
      local slug = parser.generate_slug(header.text)
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

---Update existing table of contents
---@return nil
function M.update_toc()
  local toc_location = M.find_toc()

  if not toc_location then
    print("No TOC found. Use <leader>ht to generate one.")
    return
  end

  local headers = parser.get_all_headers()

  if #headers == 0 then
    print("No headers found in document")
    return
  end

  -- Build new TOC content (between markers)
  local toc_lines = {
    "",
    "## Table of Contents",
    "",
  }

  for _, header in ipairs(headers) do
    -- Skip H1 (usually the document title)
    if header.level > 1 then
      local indent = string.rep("  ", header.level - 2)
      local slug = parser.generate_slug(header.text)
      local toc_line = indent .. "- [" .. header.text .. "](#" .. slug .. ")"
      table.insert(toc_lines, toc_line)
    end
  end

  table.insert(toc_lines, "")

  -- Replace TOC content (keep markers)
  local start_line = toc_location.start_line
  local end_line = toc_location.end_line

  -- Delete old content (between markers)
  vim.api.nvim_buf_set_lines(0, start_line, end_line - 1, false, {})

  -- Insert new content
  vim.api.nvim_buf_set_lines(0, start_line, start_line, false, toc_lines)

  print("TOC updated with " .. (#headers - 1) .. " entries")
end

return M
