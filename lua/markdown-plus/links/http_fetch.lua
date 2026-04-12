-- Async HTTP fetch module for markdown-plus.nvim smart paste
-- Wraps curl for non-blocking HTML retrieval with size and redirect limits

local M = {}
local url_security = require("markdown-plus.links.url_security")

local CURL_MAX_FILESIZE_BYTES = 1024 * 1024
local CURL_MAX_REDIRECTS = 5
local CURL_USER_AGENT = "Mozilla/5.0 (compatible; markdown-plus.nvim)"
local CURL_PROBE_FORMAT = "%{http_code}\n%{redirect_url}"
local REDIRECT_STATUS_CODES = {
  [300] = true,
  [301] = true,
  [302] = true,
  [303] = true,
  [307] = true,
  [308] = true,
}

---@param timeout number
---@return string[]
local function build_curl_base_cmd(timeout)
  return {
    "curl",
    "-fsS",
    "--compressed",
    "-m",
    tostring(timeout),
    "--max-filesize",
    tostring(CURL_MAX_FILESIZE_BYTES),
    "-A",
    CURL_USER_AGENT,
  }
end

---@param out vim.SystemCompleted
---@return string
local function format_curl_error(out)
  local stderr = vim.trim(out.stderr or "")
  if stderr == "" then
    return string.format("curl failed (%d)", out.code)
  end
  return string.format("curl failed (%d): %s", out.code, stderr)
end

---@param stdout string|nil
---@return number|nil status_code
---@return string|nil redirect_url
---@return string|nil err
local function parse_probe_output(stdout)
  local status_line, redirect_url = (stdout or ""):match("^(%d+)\n(.-)$")
  if not status_line then
    return nil, nil, "invalid redirect probe output"
  end

  local status_code = tonumber(status_line)
  if not status_code then
    return nil, nil, "invalid redirect probe status code"
  end

  redirect_url = vim.trim(redirect_url or "")
  if redirect_url == "" then
    redirect_url = nil
  end

  return status_code, redirect_url, nil
end

---@param status_code number
---@return boolean
local function is_redirect_status(status_code)
  return REDIRECT_STATUS_CODES[status_code] == true
end

---@param redirect_url string
---@return boolean is_valid
---@return string|nil reason
local function validate_redirect_url(redirect_url)
  if not url_security.is_url(redirect_url) then
    return false, "redirect target must be an HTTP(S) URL"
  end

  local is_blocked, reason = url_security.is_blocked_url(redirect_url)
  if is_blocked then
    return false, reason or "blocked host"
  end

  return true, nil
end

---@param url string
---@param timeout number
---@param callback fun(final_url: string|nil, err: string|nil)
local function resolve_final_url_async(url, timeout, callback)
  local remaining_redirects = CURL_MAX_REDIRECTS

  local function probe(current_url)
    local cmd = build_curl_base_cmd(timeout)
    table.insert(cmd, "--head")
    table.insert(cmd, "--max-redirs")
    table.insert(cmd, "0")
    table.insert(cmd, "-o")
    table.insert(cmd, "/dev/null")
    table.insert(cmd, "-w")
    table.insert(cmd, CURL_PROBE_FORMAT)
    table.insert(cmd, current_url)

    vim.system(cmd, { text = true }, function(out)
      if out.code ~= 0 then
        callback(nil, format_curl_error(out))
        return
      end

      local status_code, redirect_url, parse_err = parse_probe_output(out.stdout)
      if parse_err then
        callback(nil, parse_err)
        return
      end

      if is_redirect_status(status_code) and redirect_url then
        if remaining_redirects <= 0 then
          callback(nil, "too many redirects")
          return
        end

        local redirect_ok, reason = validate_redirect_url(redirect_url)
        if not redirect_ok then
          callback(nil, "redirect target blocked (" .. reason .. ")")
          return
        end

        remaining_redirects = remaining_redirects - 1
        probe(redirect_url)
        return
      end

      callback(current_url, nil)
    end)
  end

  probe(url)
end

---Fetch HTML content from URL asynchronously
---@param url string URL to fetch
---@param timeout number Timeout in seconds
---@param callback fun(html: string|nil, err: string|nil) Callback with result
function M.fetch_html_async(url, timeout, callback)
  local is_blocked, reason = url_security.is_blocked_url(url)
  if is_blocked then
    callback(nil, "URL blocked (" .. (reason or "blocked host") .. ")")
    return
  end

  resolve_final_url_async(url, timeout, function(final_url, resolve_err)
    if resolve_err then
      callback(nil, resolve_err)
      return
    end

    if not final_url then
      callback(nil, "unable to resolve final URL")
      return
    end

    local cmd = build_curl_base_cmd(timeout)
    table.insert(cmd, "--max-redirs")
    table.insert(cmd, "0")
    table.insert(cmd, final_url)

    vim.system(cmd, { text = true }, function(out)
      if out.code ~= 0 then
        callback(nil, format_curl_error(out))
      else
        callback(out.stdout, nil)
      end
    end)
  end)
end

-- Expose helper functions for tests
M._parse_probe_output = parse_probe_output
M._is_redirect_status = is_redirect_status
M._validate_redirect_url = validate_redirect_url
M._build_curl_base_cmd = build_curl_base_cmd

return M
