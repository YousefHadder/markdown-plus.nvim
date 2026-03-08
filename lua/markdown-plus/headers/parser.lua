-- Header parsing module for markdown-plus.nvim

local utils = require("markdown-plus.utils")

local M = {}
---@type markdown-plus.InternalConfig
local config = {}

---Header pattern (matches # through ######)
M.header_pattern = "^(#+)%s+(.+)$"

---Set module configuration
---@param cfg markdown-plus.InternalConfig
---@return nil
function M.set_config(cfg)
  config = cfg or {}
end

---Check whether HTML block awareness is enabled (default: true)
---@return boolean
local function html_awareness_enabled()
  return not (config.features and config.features.html_block_awareness == false)
end

---Parse header information from a line and optional lookahead line
---Supports both ATX headings (`# Heading`) and setext headings (`Heading` + `===/---`).
---@param line string Line to parse
---@param next_line? string Optional next line for setext detection
---@return table|nil Header info or nil if not a header
function M.parse_header(line, next_line)
  if not line then
    return nil
  end

  local hashes, text = line:match(M.header_pattern)
  if hashes and text then
    return {
      level = #hashes,
      text = text,
      hashes = hashes,
      style = "atx",
    }
  end

  if not next_line then
    return nil
  end

  local heading_text = line:match("^%s*(.-)%s*$")
  if not heading_text or heading_text == "" then
    return nil
  end

  if next_line:match("^%s*=+%s*$") then
    return {
      level = 1,
      text = heading_text,
      hashes = nil,
      style = "setext",
      underline = next_line,
    }
  end

  if next_line:match("^%s*%-+%s*$") then
    return {
      level = 2,
      text = heading_text,
      hashes = nil,
      style = "setext",
      underline = next_line,
    }
  end

  return nil
end

---Get all headers in the buffer (excluding code blocks)
---@return table[] Array of headers with {level, text, hashes, line_num, full_line}
function M.get_all_headers()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local headers = {}

  -- Use regex for full-buffer code block scanning (faster than TS tree walk)
  local code_block_lines = utils.get_code_block_lines(lines)
  local html_block_lines = {}
  if html_awareness_enabled() then
    html_block_lines = utils.get_html_block_lines(lines)
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]

    -- Only parse headers if we're not inside a code block or HTML block
    if not code_block_lines[i] and not html_block_lines[i] then
      local next_line = nil
      if i < #lines and not code_block_lines[i + 1] and not html_block_lines[i + 1] then
        next_line = lines[i + 1]
      end

      local header = M.parse_header(line, next_line)
      if header then
        header.line_num = i
        header.full_line = line
        table.insert(headers, header)

        if header.style == "setext" then
          i = i + 2
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return headers
end

---Generate GitHub-compatible slug from header text
---@param text string Header text to convert to slug
---@return string Slug suitable for TOC anchors
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

return M
