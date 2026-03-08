-- Smart paste module for markdown-plus.nvim
-- Converts pasted URLs into markdown links with fetched page titles
local M = {}

---@type markdown-plus.InternalConfig
local config = {}

-- Namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("markdown_plus_smart_paste")
local MAX_TITLE_LENGTH = 300
local MAX_SMART_PASTE_TIMEOUT = 30
local CURL_MAX_FILESIZE_BYTES = 1024 * 1024
local CURL_MAX_REDIRECTS = 5

-- =============================================================================
-- HTML Parsing Helpers
-- =============================================================================

---Unescape common HTML entities
---@param s string HTML string
---@return string Unescaped string
local function html_unescape(s)
  s = s:gsub("&amp;", "&")
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&quot;", '"')
  s = s:gsub("&#39;", "'")
  s = s:gsub("&apos;", "'")
  s = s:gsub("&#x27;", "'")
  s = s:gsub("&nbsp;", " ")
  return s
end

---Check if a string is a valid HTTP(S) URL
---@param s string String to check
---@return boolean True if string is a URL
local function is_url(s)
  return type(s) == "string" and s:match("^https?://") ~= nil
end

---Extract host from an HTTP(S) URL
---@param url string
---@return string|nil host Lowercased host (IPv6 without brackets), or nil if unavailable
local function extract_url_host(url)
  local authority = url:match("^https?://([^/%?#]+)")
  if not authority then
    return nil
  end

  -- Strip optional userinfo
  authority = authority:gsub("^.-@", "")

  -- IPv6 host is wrapped in []
  if authority:sub(1, 1) == "[" then
    local ipv6_host = authority:match("^%[([^%]]+)%]")
    if not ipv6_host or ipv6_host == "" then
      return nil
    end
    return ipv6_host:lower():gsub("%%.*$", "") -- strip zone identifier (e.g. %eth0)
  end

  -- IPv4/domain with optional :port
  local host = authority:match("^([^:]+)")
  if not host or host == "" then
    return nil
  end
  return host:lower()
end

---Check whether host is in private/local IPv4 ranges
---@param host string
---@return boolean
local function is_private_ipv4(host)
  local a, b, c, d = host:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then
    return false
  end

  a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
  if not a or not b or not c or not d then
    return false
  end
  if a > 255 or b > 255 or c > 255 or d > 255 then
    return false
  end

  return a == 10
    or a == 127
    or (a == 169 and b == 254)
    or (a == 172 and b >= 16 and b <= 31)
    or (a == 192 and b == 168)
    or a == 0
end

---Check whether host is a local/private IPv6 address
---@param host string
---@return boolean
local function is_local_ipv6(host)
  local normalized = host:lower()
  if normalized == "::1" or normalized == "::" then
    return true
  end

  -- fc00::/7 (unique local), fe80::/10 (link-local)
  return normalized:match("^f[cd]") ~= nil or normalized:match("^fe[89ab]") ~= nil
end

---Check whether URL host should be blocked for smart fetch
---@param url string
---@return boolean is_blocked
---@return string|nil reason
local function is_blocked_url(url)
  local host = extract_url_host(url)
  if not host then
    return true, "invalid URL host"
  end

  if host == "localhost" or host:match("%.localhost$") then
    return true, "localhost is not allowed"
  end

  if is_private_ipv4(host) then
    return true, "private IPv4 addresses are not allowed"
  end

  if host:find(":", 1, true) and is_local_ipv6(host) then
    return true, "local/private IPv6 addresses are not allowed"
  end

  return false, nil
end

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

---Extract title from HTML content
---Tries og:title, twitter:title, then <title> tag
---@param html string HTML content
---@return string|nil Title or nil if not found
local function parse_title(html)
  if not html or html == "" then
    return nil
  end

  -- Normalize newlines
  local h = html:gsub("\r\n", "\n")

  ---Try to extract content from a meta tag pattern
  ---@param pattern string Lua pattern
  ---@return string|nil
  local function meta_content(pattern)
    local content = h:match(pattern)
    if content then
      content = vim.trim(html_unescape(content))
      if content ~= "" then
        return content
      end
    end
    return nil
  end

  -- Try og:title (property=) - handles different attribute orders
  local og = meta_content("<meta[^>]-property=[\"']og:title[\"'][^>]-content=[\"']([^\"']-)[\"'][^>]->")
    or meta_content("<meta[^>]-content=[\"']([^\"']-)[\"'][^>]-property=[\"']og:title[\"'][^>]->")

  if og then
    return og
  end

  -- Try twitter:title (name=)
  local tw = meta_content("<meta[^>]-name=[\"']twitter:title[\"'][^>]-content=[\"']([^\"']-)[\"'][^>]->")
    or meta_content("<meta[^>]-content=[\"']([^\"']-)[\"'][^>]-name=[\"']twitter:title[\"'][^>]->")

  if tw then
    return tw
  end

  -- Try <title> tag (case-insensitive)
  local t = h:match("<[Tt][Ii][Tt][Ll][Ee][^>]*>(.-)</[Tt][Ii][Tt][Ll][Ee]>")
  if t then
    t = vim.trim(html_unescape(t:gsub("%s+", " ")))
    if t ~= "" then
      return t
    end
  end

  return nil
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
    if not content:match("\n") and is_url(content) then
      return content
    end
  end

  return nil
end

-- =============================================================================
-- Async Fetch
-- =============================================================================

---Fetch HTML content from URL asynchronously
---@param url string URL to fetch
---@param timeout number Timeout in seconds
---@param callback fun(html: string|nil, err: string|nil) Callback with result
local function fetch_html_async(url, timeout, callback)
  local cmd = {
    "curl",
    "-fsSL",
    "--compressed",
    "-m",
    tostring(timeout),
    "--max-filesize",
    tostring(CURL_MAX_FILESIZE_BYTES),
    "--max-redirs",
    tostring(CURL_MAX_REDIRECTS),
    "-A",
    "Mozilla/5.0 (compatible; markdown-plus.nvim)",
    url,
  }

  vim.system(cmd, { text = true }, function(out)
    if out.code ~= 0 then
      local err = string.format("curl failed (%d): %s", out.code, vim.trim(out.stderr or ""))
      callback(nil, err)
    else
      callback(out.stdout, nil)
    end
  end)
end

-- =============================================================================
-- Core Smart Paste Logic
-- =============================================================================

---Replace placeholder with final link text
---@param bufnr number Buffer number
---@param mark_id number Extmark ID
---@param url string Original URL
---@param title string Title for the link
local function replace_placeholder(bufnr, mark_id, url, title)
  -- Check buffer is still valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Check buffer is modifiable
  if not vim.bo[bufnr].modifiable then
    vim.notify("markdown-plus: Buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  -- Get extmark position
  local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, mark_id, { details = true })
  if not mark or #mark == 0 then
    -- Extmark was deleted (user may have undone)
    return
  end

  local row = mark[1]
  local start_col = mark[2]
  local details = mark[3]
  local end_col = details and details.end_col or start_col

  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  if #lines == 0 then
    return
  end

  local line = lines[1]

  -- Escape ] in title for markdown link text
  local safe_title = truncate_title(title):gsub("%]", "\\]")
  -- Format URL for markdown (wrap in angle brackets if contains special chars)
  local safe_url = format_url_for_markdown(url)
  local new_link = string.format("[%s](%s)", safe_title, safe_url)

  -- Replace the placeholder
  local before = line:sub(1, start_col)
  local after = line:sub(end_col + 1)
  local new_line = before .. new_link .. after

  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

  -- Delete the extmark
  vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark_id)
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
        -- User provided a title
        replace_placeholder(bufnr, mark_id, url, input)
      else
        -- User cancelled - replace with raw URL
        -- Get extmark to find placeholder position
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        -- Check buffer is modifiable
        if not vim.bo[bufnr].modifiable then
          vim.notify("markdown-plus: Buffer is not modifiable", vim.log.levels.WARN)
          return
        end

        local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, mark_id, { details = true })
        if not mark or #mark == 0 then
          return
        end

        local row = mark[1]
        local start_col = mark[2]
        local details = mark[3]
        local end_col = details and details.end_col or start_col

        local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
        if #lines == 0 then
          return
        end

        local line = lines[1]
        local before = line:sub(1, start_col)
        local after = line:sub(end_col + 1)
        local new_line = before .. url .. after

        vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark_id)
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

  local is_blocked, reason = is_blocked_url(url)
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
  fetch_html_async(url, timeout, function(html, err)
    vim.schedule(function()
      if err then
        prompt_for_title(bufnr, mark_id, url, "Failed to fetch page: " .. err)
        return
      end

      local title = parse_title(html)
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
M._html_unescape = html_unescape
M._is_url = is_url
M._parse_title = parse_title
M._get_clipboard_url = get_clipboard_url
M._url_needs_brackets = url_needs_brackets
M._format_url_for_markdown = format_url_for_markdown
M._extract_url_host = extract_url_host
M._is_blocked_url = is_blocked_url
M._clamp_timeout = clamp_timeout
M._truncate_title = truncate_title

return M
