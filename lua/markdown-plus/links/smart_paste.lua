-- Smart paste module for markdown-plus.nvim
-- Converts pasted URLs into markdown links with fetched page titles
local M = {}

local url_security = require("markdown-plus.links.url_security")
local html_parser = require("markdown-plus.links.html_parser")
local http_fetch = require("markdown-plus.links.http_fetch")

---@type markdown-plus.InternalConfig
local config = {}

-- Namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("markdown_plus_smart_paste")
local MAX_TITLE_LENGTH = 300
local MAX_SMART_PASTE_TIMEOUT = 30

---Clamp smart-paste timeout to a safe range
---@param timeout number|nil
---@return number
local function clamp_timeout(timeout)
  local value = tonumber(timeout) or 5
  if value < 1 then
    return 1
  end
  if value > MAX_SMART_PASTE_TIMEOUT then
    return MAX_SMART_PASTE_TIMEOUT
  end
  return value
end

---Truncate fetched titles to keep inserted links bounded
---@param title string
---@return string
local function truncate_title(title)
  if #title <= MAX_TITLE_LENGTH then
    return title
  end
  return title:sub(1, MAX_TITLE_LENGTH - 3) .. "..."
end

---Check if URL needs angle bracket wrapping for markdown
---URLs with parentheses, spaces, or other special characters need wrapping
---@param url string URL to check
---@return boolean True if URL needs angle brackets
local function url_needs_brackets(url)
  -- Parentheses break markdown link syntax: [text](url(with)parens) is invalid
  -- Spaces and angle brackets also need special handling
  return url:match("[()%s<>]") ~= nil
end

---Format URL for use in markdown link syntax
---Wraps URL in angle brackets if it contains special characters
---@param url string URL to format
---@return string Formatted URL safe for markdown
local function format_url_for_markdown(url)
  if url_needs_brackets(url) then
    return "<" .. url .. ">"
  end
  return url
end

---Get URL from system clipboard
---@return string|nil URL or nil if clipboard doesn't contain a URL
local function get_clipboard_url()
  local content = vim.fn.getreg("+")
  if not content or content == "" then
    -- Try unnamed register as fallback
    content = vim.fn.getreg('"')
  end

  if content then
    -- Trim whitespace
    content = vim.trim(content)
    -- Check if it's a single-line URL
    if not content:match("\n") and url_security.is_url(content) then
      return content
    end
  end

  return nil
end

-- =============================================================================
-- Core Smart Paste Logic
-- =============================================================================

---Replace text at an extmark position and delete the extmark
---@param bufnr number Buffer number
---@param mark_id number Extmark ID
---@param text string Replacement text
---@return boolean success Whether the replacement was performed
local function replace_at_mark(bufnr, mark_id, text)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].modifiable then
    vim.notify("markdown-plus: Buffer is not modifiable", vim.log.levels.WARN)
    return false
  end

  local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, mark_id, { details = true })
  if not mark or #mark == 0 then
    return false
  end

  local row = mark[1]
  local start_col = mark[2]
  local details = mark[3]
  local end_col = details and details.end_col or start_col

  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  if #lines == 0 then
    return false
  end

  local line = lines[1]
  local before = line:sub(1, start_col)
  local after = line:sub(end_col + 1)
  local new_line = before .. text .. after

  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
  vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark_id)
  return true
end

---Replace placeholder with final link text
---@param bufnr number Buffer number
---@param mark_id number Extmark ID
---@param url string Original URL
---@param title string Title for the link
local function replace_placeholder(bufnr, mark_id, url, title)
  local safe_title = truncate_title(title):gsub("%]", "\\]")
  local safe_url = format_url_for_markdown(url)
  local new_link = string.format("[%s](%s)", safe_title, safe_url)
  replace_at_mark(bufnr, mark_id, new_link)
end

---Prompt user for title input
---@param bufnr number Buffer number
---@param mark_id number Extmark ID
---@param url string Original URL
---@param err_msg string|nil Error message to show
local function prompt_for_title(bufnr, mark_id, url, err_msg)
  if err_msg then
    vim.notify("markdown-plus: " .. err_msg, vim.log.levels.WARN)
  end

  vim.ui.input({ prompt = "Link title: " }, function(input)
    vim.schedule(function()
      if input and input ~= "" then
        replace_placeholder(bufnr, mark_id, url, input)
      else
        replace_at_mark(bufnr, mark_id, url)
      end
    end)
  end)
end

---Main smart paste function - reads URL from clipboard and creates markdown link
function M.smart_paste()
  -- Check if feature is enabled
  if not config.links or not config.links.smart_paste or not config.links.smart_paste.enabled then
    vim.notify("markdown-plus: Smart paste is not enabled", vim.log.levels.WARN)
    return
  end

  local url = get_clipboard_url()
  if not url then
    vim.notify("markdown-plus: No URL in clipboard", vim.log.levels.WARN)
    return
  end

  local is_blocked, reason = url_security.is_blocked_url(url)
  if is_blocked then
    vim.notify("markdown-plus: Refusing to fetch URL (" .. (reason or "blocked host") .. ")", vim.log.levels.WARN)
    return
  end

  -- Check buffer is modifiable before inserting placeholder
  if not vim.bo.modifiable then
    vim.notify("markdown-plus: Buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]

  -- Get current line
  local line = vim.api.nvim_get_current_line()

  -- Create placeholder (format URL for markdown safety)
  local safe_url = format_url_for_markdown(url)
  local placeholder = "[⏳ Loading...](" .. safe_url .. ")"

  -- Insert placeholder at cursor position
  local before = line:sub(1, col)
  local after = line:sub(col + 1)
  local new_line = before .. placeholder .. after
  vim.api.nvim_set_current_line(new_line)

  -- Create extmark to track placeholder position
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
    end_col = col + #placeholder,
    right_gravity = false,
    end_right_gravity = true,
  })

  -- Move cursor after placeholder
  vim.api.nvim_win_set_cursor(0, { row + 1, col + #placeholder })

  -- Fetch title asynchronously
  local timeout = clamp_timeout(config.links.smart_paste.timeout or 5)
  http_fetch.fetch_html_async(url, timeout, function(html, err)
    vim.schedule(function()
      if err then
        prompt_for_title(bufnr, mark_id, url, "Failed to fetch page: " .. err)
        return
      end

      local title = html_parser.parse_title(html)
      if title then
        replace_placeholder(bufnr, mark_id, url, title)
      else
        prompt_for_title(bufnr, mark_id, url, "Could not extract title from page")
      end
    end)
  end)
end

-- =============================================================================
-- Module Setup
-- =============================================================================

---Setup smart paste module
---@param cfg markdown-plus.InternalConfig Plugin configuration
function M.setup(cfg)
  config = cfg or {}
end

-- Expose helpers for testing
M._html_unescape = html_parser.html_unescape
M._is_url = url_security.is_url
M._parse_title = html_parser.parse_title
M._get_clipboard_url = get_clipboard_url
M._url_needs_brackets = url_needs_brackets
M._format_url_for_markdown = format_url_for_markdown
M._extract_url_host = url_security.extract_url_host
M._is_blocked_url = url_security.is_blocked_url
M._clamp_timeout = clamp_timeout
M._truncate_title = truncate_title

return M
