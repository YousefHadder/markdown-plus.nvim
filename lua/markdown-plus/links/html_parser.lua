-- HTML parsing helpers for markdown-plus.nvim smart paste
-- Extracts page titles from HTML content using meta tags and <title> element

local M = {}

---Unescape common HTML entities
---@param s string HTML string
---@return string Unescaped string
function M.html_unescape(s)
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

---Extract title from HTML content
---Tries og:title, twitter:title, then <title> tag
---@param html string HTML content
---@return string|nil Title or nil if not found
function M.parse_title(html)
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
      content = vim.trim(M.html_unescape(content))
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
    t = vim.trim(M.html_unescape(t:gsub("%s+", " ")))
    if t ~= "" then
      return t
    end
  end

  return nil
end

return M
