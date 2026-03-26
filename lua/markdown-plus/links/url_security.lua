-- URL security module for markdown-plus.nvim
--
-- SSRF Threat Model:
-- Smart paste fetches HTML from user-supplied URLs via curl. Without
-- validation an attacker could craft a clipboard URL pointing at internal
-- services (localhost, private RFC-1918 ranges, link-local IPv6, or
-- IPv6-mapped IPv4 addresses). This module rejects such URLs before any
-- network request is made, preventing Server-Side Request Forgery in the
-- user's editing environment.

local M = {}

---Check if a string is a valid HTTP(S) URL
---@param s string String to check
---@return boolean True if string is a URL
function M.is_url(s)
  return type(s) == "string" and s:match("^https?://") ~= nil
end

---Extract host from an HTTP(S) URL
---@param url string
---@return string|nil host Lowercased host (IPv6 without brackets), or nil if unavailable
function M.extract_url_host(url)
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
function M.is_private_ipv4(host)
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
function M.is_local_ipv6(host)
  local normalized = host:lower()
  if normalized == "::1" or normalized == "::" then
    return true
  end

  -- fc00::/7 (unique local), fe80::/10 (link-local)
  return normalized:match("^f[cd]") ~= nil or normalized:match("^fe[89ab]") ~= nil
end

---Extract embedded IPv4 from IPv6-mapped IPv4 hosts (e.g. ::ffff:127.0.0.1)
---@param host string
---@return string|nil
function M.extract_mapped_ipv4(host)
  local normalized = host:lower()
  return normalized:match("^::ffff:(%d+%.%d+%.%d+%.%d+)$")
end

---Check whether URL host should be blocked for smart fetch
---@param url string
---@return boolean is_blocked
---@return string|nil reason
function M.is_blocked_url(url)
  local host = M.extract_url_host(url)
  if not host then
    return true, "invalid URL host"
  end

  if host == "localhost" or host:match("%.localhost$") then
    return true, "localhost is not allowed"
  end

  if M.is_private_ipv4(host) then
    return true, "private IPv4 addresses are not allowed"
  end

  local mapped_ipv4 = host:find(":", 1, true) and M.extract_mapped_ipv4(host) or nil
  if mapped_ipv4 and M.is_private_ipv4(mapped_ipv4) then
    return true, "IPv6-mapped private IPv4 addresses are not allowed"
  end

  if host:find(":", 1, true) and M.is_local_ipv6(host) then
    return true, "local/private IPv6 addresses are not allowed"
  end

  return false, nil
end

return M
