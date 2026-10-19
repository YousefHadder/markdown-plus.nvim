-- URL security module for markdown-plus.nvim
--
-- SSRF Threat Model:
-- Smart paste fetches HTML from user-supplied URLs via curl. Without
-- validation an attacker could craft a clipboard URL pointing at internal
-- services (localhost, private RFC-1918 ranges, link-local IPv6, or
-- IPv6-mapped IPv4 addresses). The fetcher resolves hostnames and pins
-- validated addresses so curl cannot contact a different destination.

local M = {}

local IPV4_MAX = 4294967295

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

---Extract the effective port from an HTTP(S) URL.
---@param url string
---@return number|nil port
function M.extract_url_port(url)
  local scheme, authority = url:match("^(https?)://([^/%?#]+)")
  if not authority then
    return nil
  end

  authority = authority:gsub("^.-@", "")
  local port

  if authority:sub(1, 1) == "[" then
    local suffix = authority:match("^%[[^%]]+%](.*)$")
    if suffix == "" then
      port = nil
    elseif suffix then
      port = suffix:match("^:(%d+)$")
      if not port then
        return nil
      end
    else
      return nil
    end
  else
    local host, explicit_port = authority:match("^([^:]+):(%d+)$")
    if host then
      port = explicit_port
    elseif authority:find(":", 1, true) then
      return nil
    end
  end

  local value = tonumber(port) or (scheme == "https" and 443 or 80)
  if value < 1 or value > 65535 then
    return nil
  end
  return value
end

---@param component string
---@return number|nil
local function parse_ipv4_component(component)
  local base = 10
  local digits = component

  if component:match("^0[xX]") then
    base = 16
    digits = component:sub(3)
  elseif #component > 1 and component:sub(1, 1) == "0" then
    base = 8
    digits = component:sub(2)
  end

  local valid_digits = base == 16 and digits:match("^%x+$")
    or base == 8 and digits:match("^[0-7]+$")
    or base == 10 and digits:match("^%d+$")
  if not valid_digits then
    return nil
  end

  return tonumber(digits, base)
end

---Normalize decimal, octal, hexadecimal, and shortened IPv4 forms.
---@param host string
---@return string|nil normalized
function M.normalize_ipv4(host)
  local components = {}
  for component in host:gmatch("[^%.]+") do
    components[#components + 1] = component
  end

  if #components < 1 or #components > 4 or table.concat(components, ".") ~= host then
    return nil
  end

  local values = {}
  for index, component in ipairs(components) do
    local value = parse_ipv4_component(component)
    if not value then
      return nil
    end
    values[index] = value
  end

  local last_component_max = 2 ^ (8 * (5 - #values)) - 1
  if values[#values] > last_component_max then
    return nil
  end
  for index = 1, #values - 1 do
    if values[index] > 255 then
      return nil
    end
  end

  local address = values[#values]
  for index = #values - 1, 1, -1 do
    address = address + values[index] * (2 ^ (8 * (4 - index)))
  end
  if address > IPV4_MAX then
    return nil
  end

  local a = math.floor(address / 16777216)
  local b = math.floor(address / 65536) % 256
  local c = math.floor(address / 256) % 256
  local d = address % 256
  return string.format("%d.%d.%d.%d", a, b, c, d)
end

---Check whether host is in private/local IPv4 ranges
---@param host string
---@return boolean
function M.is_private_ipv4(host)
  local normalized = M.normalize_ipv4(host)
  local a, b, c, d = (normalized or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
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

---Extract embedded IPv4 from IPv4-compatible IPv6 hosts.
---@param host string
---@return string|nil
function M.extract_compatible_ipv4(host)
  local normalized = host:lower()
  return normalized:match("^::(%d+%.%d+%.%d+%.%d+)$")
end

---Check whether a host name or address identifies a local/private destination.
---@param host string
---@return boolean is_blocked
---@return string|nil reason
function M.is_blocked_host(host)
  local normalized = host:lower()
  if normalized:sub(-1) == "." then
    normalized = normalized:sub(1, -2)
  end

  if normalized == "" or normalized:sub(-1) == "." then
    return true, "invalid URL host"
  end

  if normalized == "localhost" or normalized:match("%.localhost$") then
    return true, "localhost is not allowed"
  end

  if M.is_private_ipv4(normalized) then
    return true, "private IPv4 addresses are not allowed"
  end
  if normalized:match("^[%d%.]+$") or normalized:match("^0[xX]") then
    if M.normalize_ipv4(normalized) then
      return false, nil
    end
    return true, "invalid IPv4 address"
  end

  local mapped_ipv4 = normalized:find(":", 1, true) and M.extract_mapped_ipv4(normalized) or nil
  if mapped_ipv4 and M.is_private_ipv4(mapped_ipv4) then
    return true, "IPv6-mapped private IPv4 addresses are not allowed"
  end

  local compatible_ipv4 = normalized:find(":", 1, true) and M.extract_compatible_ipv4(normalized) or nil
  if compatible_ipv4 and M.is_private_ipv4(compatible_ipv4) then
    return true, "IPv4-compatible private IPv6 addresses are not allowed"
  end

  if normalized:find(":", 1, true) and M.is_local_ipv6(normalized) then
    return true, "local/private IPv6 addresses are not allowed"
  end

  return false, nil
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

  return M.is_blocked_host(host)
end

return M
