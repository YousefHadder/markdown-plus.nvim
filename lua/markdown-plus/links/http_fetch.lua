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
    "--noproxy",
    "*",
  }
end

---@class markdown-plus.links.ResolvedDestination
---@field url string
---@field host string
---@field port number
---@field addresses string[]|nil

---@param url string
---@param host string
---@return string
local function replace_url_host(url, host)
  local scheme, authority, suffix = url:match("^(https?://)([^/%?#]+)(.*)$")
  if not authority then
    return url
  end

  local userinfo, host_port = authority:match("^(.-@)(.*)$")
  if not userinfo then
    userinfo, host_port = "", authority
  end

  local port_suffix = host_port:match("^[^:]+(:%d+)$") or ""
  return scheme .. userinfo .. host .. port_suffix .. suffix
end

---@param url string
---@param timeout number
---@param callback fun(destination: markdown-plus.links.ResolvedDestination|nil, err: string|nil)
local function resolve_destination_async(url, timeout, callback)
  if not url_security.is_url(url) then
    callback(nil, "URL must use HTTP or HTTPS")
    return
  end

  local is_blocked, reason = url_security.is_blocked_url(url)
  if is_blocked then
    callback(nil, "URL blocked (" .. (reason or "blocked host") .. ")")
    return
  end

  local host = url_security.extract_url_host(url)
  local port = url_security.extract_url_port(url)
  if not host or not port then
    callback(nil, "invalid URL host or port")
    return
  end

  local normalized_ipv4 = url_security.normalize_ipv4(host)
  if normalized_ipv4 then
    callback({
      url = normalized_ipv4 == host and url or replace_url_host(url, normalized_ipv4),
      host = normalized_ipv4,
      port = port,
    }, nil)
    return
  end

  local is_ipv6_literal = host:find(":", 1, true) ~= nil

  local timer, timer_err = vim.uv.new_timer()
  if not timer then
    callback(nil, "unable to resolve host (timer creation failed: " .. tostring(timer_err) .. ")")
    return
  end

  local completed = false
  local request

  ---@param destination markdown-plus.links.ResolvedDestination|nil
  ---@param err string|nil
  ---@param timed_out boolean|nil
  local function finish(destination, err, timed_out)
    if completed then
      return
    end
    completed = true
    timer:stop()
    timer:close()
    if timed_out and request then
      -- Cancellation may return EBUSY; the completion guard also rejects late replies.
      vim.uv.cancel(request)
    end
    callback(destination, err)
  end

  local started, start_err = timer:start(timeout * 1000, 0, function()
    finish(nil, "unable to resolve host (timed out)", true)
  end)
  if not started then
    finish(nil, "unable to resolve host (timer start failed: " .. tostring(start_err) .. ")")
    return
  end

  local ok, request_or_err, submission_err = pcall(
    vim.uv.getaddrinfo,
    host,
    nil,
    { socktype = "stream" },
    function(err, results)
      if completed then
        return
      end
      if err then
        finish(nil, "unable to resolve host (" .. tostring(err) .. ")")
        return
      end

      local addresses = {}
      local seen = {}
      for _, result in ipairs(results or {}) do
        local ip = result.addr
        if ip then
          local address_blocked, address_reason = url_security.is_blocked_host(ip)
          if address_blocked then
            finish(nil, "URL blocked (" .. (address_reason or "blocked address") .. ")")
            return
          end

          local formatted_ip = result.family == "inet6" and ("[" .. ip .. "]") or ip
          if not seen[formatted_ip] then
            seen[formatted_ip] = true
            addresses[#addresses + 1] = formatted_ip
          end
        end
      end

      if #addresses == 0 then
        finish(nil, "unable to resolve host (no addresses)")
        return
      end

      if is_ipv6_literal then
        finish({ url = url, host = host, port = port }, nil)
        return
      end

      finish({
        url = url,
        host = host,
        port = port,
        addresses = addresses,
      }, nil)
    end
  )

  if not ok then
    finish(nil, "unable to resolve host (" .. tostring(request_or_err) .. ")")
  elseif not request_or_err then
    finish(nil, "unable to resolve host (" .. tostring(submission_err) .. ")")
  else
    request = request_or_err
  end
end

---@param cmd string[]
---@param destination markdown-plus.links.ResolvedDestination
local function append_destination_options(cmd, destination)
  if destination.addresses then
    table.insert(cmd, "--resolve")
    table.insert(
      cmd,
      string.format("%s:%d:%s", destination.host, destination.port, table.concat(destination.addresses, ","))
    )
  end
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

---@param destination markdown-plus.links.ResolvedDestination
---@param timeout number
---@param callback fun(final_destination: markdown-plus.links.ResolvedDestination|nil, err: string|nil)
local function resolve_final_url_async(destination, timeout, callback)
  local remaining_redirects = CURL_MAX_REDIRECTS

  local function probe(current_destination)
    local cmd = build_curl_base_cmd(timeout)
    table.insert(cmd, "--head")
    table.insert(cmd, "--max-redirs")
    table.insert(cmd, "0")
    table.insert(cmd, "-o")
    table.insert(cmd, "/dev/null")
    table.insert(cmd, "-w")
    table.insert(cmd, CURL_PROBE_FORMAT)
    append_destination_options(cmd, current_destination)
    table.insert(cmd, current_destination.url)

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

        local redirect_ok, redirect_reason = validate_redirect_url(redirect_url)
        if not redirect_ok then
          callback(nil, "redirect target blocked (" .. redirect_reason .. ")")
          return
        end

        resolve_destination_async(redirect_url, timeout, function(redirect_destination, resolve_err)
          if resolve_err then
            callback(nil, "redirect target blocked (" .. resolve_err .. ")")
            return
          end

          remaining_redirects = remaining_redirects - 1
          probe(redirect_destination)
        end)
        return
      end

      callback(current_destination, nil)
    end)
  end

  probe(destination)
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

  resolve_destination_async(url, timeout, function(destination, destination_err)
    if destination_err then
      callback(nil, destination_err)
      return
    end

    resolve_final_url_async(destination, timeout, function(final_destination, resolve_err)
      if resolve_err then
        callback(nil, resolve_err)
        return
      end

      if not final_destination then
        callback(nil, "unable to resolve final URL")
        return
      end

      local cmd = build_curl_base_cmd(timeout)
      table.insert(cmd, "--max-redirs")
      table.insert(cmd, "0")
      append_destination_options(cmd, final_destination)
      table.insert(cmd, final_destination.url)

      vim.system(cmd, { text = true }, function(out)
        if out.code ~= 0 then
          callback(nil, format_curl_error(out))
        else
          callback(out.stdout, nil)
        end
      end)
    end)
  end)
end

-- Expose helper functions for tests
M._parse_probe_output = parse_probe_output
M._is_redirect_status = is_redirect_status
M._validate_redirect_url = validate_redirect_url
M._build_curl_base_cmd = build_curl_base_cmd

return M
