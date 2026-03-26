-- Async HTTP fetch module for markdown-plus.nvim smart paste
-- Wraps curl for non-blocking HTML retrieval with size and redirect limits

local M = {}

local CURL_MAX_FILESIZE_BYTES = 1024 * 1024
local CURL_MAX_REDIRECTS = 5

---Fetch HTML content from URL asynchronously
---@param url string URL to fetch
---@param timeout number Timeout in seconds
---@param callback fun(html: string|nil, err: string|nil) Callback with result
function M.fetch_html_async(url, timeout, callback)
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

return M
