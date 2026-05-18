---@module 'markdown-plus.table.cell_breaks'
---@brief [[
--- Centralized parsing of <br>-style line breaks inside markdown table cells.
---
--- GFM forbids real newlines inside table cells. The canonical way to force a
--- visual line break is the HTML <br> tag. This module is the single source of
--- truth for splitting cells on <br>, joining segments back together, and
--- detecting whether a cell contains a break.
---
--- Recognised break tokens (all case-insensitive): <br>, <br/>, <br />.
---
--- Inline-code spans (backtick-fenced text) are shielded so a literal `<br>`
--- inside an inline code span is NOT treated as a break. Only single-backtick
--- spans are recognised; multi-backtick spans fall back to literal handling.
---@brief ]]

local M = {}

-- Pattern matches <br>, <br/>, <br /> with optional internal whitespace and any case.
local BR_PATTERN = "<[bB][rR]%s*/?>"

---Find inline-code spans inside a cell so <br> tokens inside them can be skipped.
---Single-backtick spans only; balanced pairs scanned greedily left-to-right.
---@param cell string
---@return {first: integer, last: integer}[] ranges 1-indexed inclusive byte ranges
local function find_code_spans(cell)
  local ranges = {}
  local i = 1
  while i <= #cell do
    local s, e = cell:find("`[^`]*`", i)
    if not s then
      break
    end
    ranges[#ranges + 1] = { first = s, last = e }
    i = e + 1
  end
  return ranges
end

---@param pos integer
---@param ranges {first: integer, last: integer}[]
---@return boolean
local function inside_ranges(pos, ranges)
  for _, r in ipairs(ranges) do
    if pos >= r.first and pos <= r.last then
      return true
    end
  end
  return false
end

---Split a cell into segments on every <br> variant outside inline code spans.
---Always returns at least one segment. An empty cell yields {""}.
---@param cell string|nil Cell content (already pipe-trimmed)
---@return string[] segments
function M.split_segments(cell)
  if cell == nil or cell == "" then
    return { cell or "" }
  end
  local code_ranges = find_code_spans(cell)
  local segments = {}
  local segment_start = 1
  local search_from = 1
  while search_from <= #cell do
    local s, e = cell:find(BR_PATTERN, search_from)
    if not s then
      break
    end
    if inside_ranges(s, code_ranges) then
      -- Shielded match: keep the current segment open, just continue scanning.
      search_from = e + 1
    else
      -- Real break: close the current segment and start a new one.
      segments[#segments + 1] = cell:sub(segment_start, s - 1)
      segment_start = e + 1
      search_from = e + 1
    end
  end
  segments[#segments + 1] = cell:sub(segment_start)
  return segments
end

---Detect whether a cell contains at least one <br> token outside inline code spans.
---@param cell string|nil
---@return boolean
function M.has_break(cell)
  if cell == nil or cell == "" then
    return false
  end
  local code_ranges = find_code_spans(cell)
  local cursor = 1
  while cursor <= #cell do
    local s, e = cell:find(BR_PATTERN, cursor)
    if not s then
      return false
    end
    if not inside_ranges(s, code_ranges) then
      return true
    end
    cursor = e + 1
  end
  return false
end

---Join an array of segments into a single cell string using the given break token.
---Empty segments are preserved so consecutive breaks round-trip cleanly.
---@param segments string[]|nil
---@param wrap_break? string Break token to insert between segments (default: "<br>")
---@return string
function M.join_segments(segments, wrap_break)
  wrap_break = wrap_break or "<br>"
  if not segments or #segments == 0 then
    return ""
  end
  return table.concat(segments, wrap_break)
end

---Collapse every <br> variant in a cell to a single space, then collapse runs
---of whitespace and trim. Useful for one-line previews and the unwrap command.
---@param cell string|nil
---@return string
function M.unwrap(cell)
  if cell == nil or cell == "" then
    return cell or ""
  end
  local segments = M.split_segments(cell)
  local joined = table.concat(segments, " ")
  joined = joined:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return joined
end

---Tokenize a string into whitespace-separated words while treating inline-code
---spans (backtick-fenced text) as single atomic tokens — even if the span
---itself contains whitespace.
---@param cell string
---@return string[] tokens
local function tokenize_words(cell)
  if cell == nil or cell == "" then
    return {}
  end
  local code_ranges = find_code_spans(cell)
  local tokens = {}
  local buffer = ""
  local i = 1
  while i <= #cell do
    local range_end = nil
    for _, r in ipairs(code_ranges) do
      if i >= r.first and i <= r.last then
        range_end = r.last
        break
      end
    end
    if range_end then
      buffer = buffer .. cell:sub(i, range_end)
      i = range_end + 1
    else
      local char = cell:sub(i, i)
      if char:match("%s") then
        if buffer ~= "" then
          tokens[#tokens + 1] = buffer
          buffer = ""
        end
      else
        buffer = buffer .. char
      end
      i = i + 1
    end
  end
  if buffer ~= "" then
    tokens[#tokens + 1] = buffer
  end
  return tokens
end

---Greedy word-wrap a cell to a maximum width, inserting `wrap_break` at word
---boundaries. Existing `<br>` variants are flattened first so the result is
---deterministic and idempotent at the same width.
---
---Long single words (longer than width) are kept intact on their own line —
---this function never splits a word mid-character. Inline-code spans
---(backtick-fenced text) are treated as atomic tokens, so wrapping never
---occurs inside a code span even if the span itself contains spaces.
---
---Widths are measured in display cells via `vim.fn.strwidth`, so multibyte
---and wide characters are handled correctly.
---@param cell string|nil
---@param width integer Target width (>= 1)
---@param wrap_break? string Break token used between resulting lines (default: "<br>")
---@return string
function M.wrap_text(cell, width, wrap_break)
  wrap_break = wrap_break or "<br>"
  if cell == nil or cell == "" or width == nil or width < 1 then
    return cell or ""
  end
  -- Flatten existing <br>s so the wrap is independent of prior break placement.
  local segments = M.split_segments(cell)
  local flat = table.concat(segments, " ")
  local words = tokenize_words(flat)
  if #words == 0 then
    return ""
  end

  local lines = {}
  local current = ""
  local current_width = 0
  for _, word in ipairs(words) do
    local word_width = vim.fn.strwidth(word)
    if current == "" then
      current = word
      current_width = word_width
    elseif current_width + 1 + word_width <= width then
      current = current .. " " .. word
      current_width = current_width + 1 + word_width
    else
      lines[#lines + 1] = current
      current = word
      current_width = word_width
    end
  end
  if current ~= "" then
    lines[#lines + 1] = current
  end
  return M.join_segments(lines, wrap_break)
end

return M
