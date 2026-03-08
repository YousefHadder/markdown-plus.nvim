-- Format detection module for markdown-plus.nvim
-- Contains functions for detecting, adding, removing, and stripping formatting

local patterns = require("markdown-plus.format.patterns")

local M = {}

---@param text string
---@param pos number 1-indexed position
---@return boolean
local function is_escaped(text, pos)
  local slash_count = 0
  local i = pos - 1
  while i >= 1 and text:sub(i, i) == "\\" do
    slash_count = slash_count + 1
    i = i - 1
  end
  return slash_count % 2 == 1
end

---@param text string
---@param marker string
---@param init number
---@return number|nil
local function find_unescaped(text, marker, init)
  local i = init
  while i <= #text do
    local pos = text:find(marker, i, true)
    if not pos then
      return nil
    end
    if not is_escaped(text, pos) then
      return pos
    end
    i = pos + 1
  end
  return nil
end

---@param text string
---@param marker string
---@return boolean
local function contains_unescaped_pair(text, marker)
  local marker_len = #marker
  local open_pos = find_unescaped(text, marker, 1)
  while open_pos do
    local close_pos = find_unescaped(text, marker, open_pos + marker_len)
    if close_pos and close_pos > open_pos + marker_len - 1 then
      return true
    end
    open_pos = find_unescaped(text, marker, open_pos + 1)
  end
  return false
end

---@param text string
---@param marker string
---@return string
local function strip_unescaped_pairs(text, marker)
  local marker_len = #marker
  local result = {}
  local cursor = 1

  while true do
    local open_pos = find_unescaped(text, marker, cursor)
    if not open_pos then
      table.insert(result, text:sub(cursor))
      break
    end

    local close_pos = find_unescaped(text, marker, open_pos + marker_len)
    if not close_pos then
      table.insert(result, text:sub(cursor))
      break
    end

    table.insert(result, text:sub(cursor, open_pos - 1))
    table.insert(result, text:sub(open_pos + marker_len, close_pos - 1))
    cursor = close_pos + marker_len
  end

  return table.concat(result)
end

---Check if text has specific formatting markers wrapping it
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text has the specified formatting
function M.has_formatting(text, format_type)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return false
  end

  local marker = pattern.wrap
  local marker_len = #marker

  if #text < marker_len * 2 then
    return false
  end

  if text:sub(1, marker_len) ~= marker then
    return false
  end

  local end_pos = #text - marker_len + 1
  if text:sub(end_pos, #text) ~= marker then
    return false
  end

  return not is_escaped(text, end_pos)
end

---Add formatting markers to text
---@param text string The text to format
---@param format_type string The format type to add
---@return string The formatted text
function M.add_formatting(text, format_type)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return text
  end

  return pattern.wrap .. text .. pattern.wrap
end

---Remove formatting markers from text (outer markers only)
---@param text string The text to unformat
---@param format_type string The format type to remove
---@return string The unformatted text
function M.remove_formatting(text, format_type)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return text
  end

  if not M.has_formatting(text, format_type) then
    return text
  end

  local marker_len = #pattern.wrap
  local start_pos = marker_len + 1
  local end_pos = #text - marker_len

  if start_pos > end_pos then
    return ""
  end

  return text:sub(start_pos, end_pos)
end

---Strip all formatting markers from text
---Processes in order from longest to shortest markers to avoid breaking patterns
---@param text string The text to strip all formatting from
---@return string The text with all formatting removed
function M.strip_all_formatting(text)
  local result = text
  result = M.strip_format_type(result, "bold")
  result = M.strip_format_type(result, "strikethrough")
  result = M.strip_format_type(result, "highlight")
  result = M.strip_format_type(result, "underline")
  result = M.strip_format_type(result, "italic")
  result = M.strip_format_type(result, "code")

  return result
end

---Check if text contains any instances of the specified formatting (not just wrapping)
---Unlike has_formatting() which checks if text is wrapped with markers,
---this checks if the formatting exists anywhere within the text.
---@param text string The text to check
---@param format_type string The format type to check for
---@return boolean True if text contains the formatting anywhere
function M.contains_formatting(text, format_type)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return false
  end

  -- ITALIC DETECTION ALGORITHM
  -- ===========================
  -- Detecting italic is complex because * is used for both italic (*text*) and bold (**text**).
  -- We cannot use a simple pattern like "%*(.-)%*" because it would match the inner ** of bold.
  --
  -- The algorithm scans the text character by character looking for asterisks, then classifies
  -- each asterisk based on its surrounding characters:
  --
  -- Asterisk classification rules:
  -- - Single * (not preceded or followed by *): italic marker
  -- - ** (two consecutive *): bold marker
  -- - *** (three consecutive *): italic + bold combined (first/last * is italic, middle ** is bold)
  --
  -- Opening italic asterisk criteria:
  -- 1. NOT preceded by * (otherwise it's part of ** or end of bold)
  -- 2. AND either:
  --    a. NOT followed by * (simple italic: *text*), OR
  --    b. Followed by ** (triple: ***text*** where first * is italic)
  --
  -- Closing italic asterisk criteria (mirror of opening):
  -- 1. NOT followed by * (otherwise it's part of ** or start of bold)
  -- 2. AND either:
  --    a. NOT preceded by * (simple italic), OR
  --    b. Preceded by ** (triple: ***text*** where last * is italic)
  if format_type == "italic" then
    local i = 1
    while i <= #text do
      -- Find next asterisk in the text
      local start_pos = text:find("%*", i)
      if not start_pos then
        break
      end

      if is_escaped(text, start_pos) then
        i = start_pos + 1
      else
        -- Examine characters surrounding this asterisk to classify it
        local char_before = start_pos > 1 and text:sub(start_pos - 1, start_pos - 1) or ""
        local char_after = text:sub(start_pos + 1, start_pos + 1) or ""
        local char_after2 = text:sub(start_pos + 2, start_pos + 2) or ""

        -- Classify the asterisk based on neighbors
        local is_preceded_by_star = char_before == "*"
        local is_followed_by_star = char_after == "*"
        local is_triple = is_followed_by_star and char_after2 == "*" -- Check for ***

        -- Apply opening italic criteria (see algorithm description above)
        local is_italic_star = not is_preceded_by_star and (not is_followed_by_star or is_triple)

        if is_italic_star then
          -- Found potential opening italic marker, now search for matching closing marker
          local search_start = start_pos + 1
          if is_triple then
            search_start = start_pos + 3 -- For ***, skip all three to find content
          end

          local j = search_start
          while j <= #text do
            local end_pos = text:find("%*", j)
            if not end_pos then
              break
            end

            if not is_escaped(text, end_pos) then
              -- Examine characters surrounding potential closing asterisk
              local end_char_before = text:sub(end_pos - 1, end_pos - 1) or ""
              local end_char_after = text:sub(end_pos + 1, end_pos + 1) or ""
              local end_char_before2 = end_pos > 2 and text:sub(end_pos - 2, end_pos - 2) or ""

              local end_preceded_by_star = end_char_before == "*"
              local end_followed_by_star = end_char_after == "*"
              local end_is_triple = end_preceded_by_star and end_char_before2 == "*"

              -- Apply closing italic criteria (see algorithm description above)
              local is_closing_italic = not end_followed_by_star and (not end_preceded_by_star or end_is_triple)

              if is_closing_italic then
                return true -- Found valid italic pair
              end
            end

            j = end_pos + 1
          end
        end

        -- Advance scan position, skipping over bold/triple markers to avoid re-examining
        if is_triple then
          i = start_pos + 3 -- Skip *** (italic+bold marker)
        elseif is_followed_by_star then
          i = start_pos + 2 -- Skip ** (bold marker)
        else
          i = start_pos + 1 -- Single *, move to next character
        end
      end
    end
    return false
  end

  -- For bold, we need to ensure we match ** not single *
  if format_type == "bold" then
    return contains_unescaped_pair(text, "**")
  end

  -- For other formats, look for unescaped delimiter pairs
  return contains_unescaped_pair(text, pattern.wrap)
end

---Strip a specific format type from text (removes all instances)
---Unlike strip_all_formatting() which removes all formats, this only removes
---the specified format type, preserving other formatting.
---@param text string The text to process
---@param format_type string The format type to strip
---@return string The text with the specific formatting removed
function M.strip_format_type(text, format_type)
  local pattern = patterns.patterns[format_type]
  if not pattern then
    return text
  end

  -- ITALIC STRIPPING STRATEGY
  -- =========================
  -- We need to remove single * pairs without affecting ** (bold markers).
  -- A simple gsub("%*(.-)%*", "%1") would incorrectly match bold markers.
  --
  -- Strategy: Use placeholder substitution
  -- 1. Replace all ** with a unique placeholder
  -- 2. Strip remaining * pairs (which are now guaranteed to be italic)
  -- 3. Restore ** from placeholder
  --
  -- Placeholder choice: We use control characters \001\002 (SOH + STX)
  -- This is safe because markdown text content should never contain these
  -- ASCII control characters - they're non-printable and have no meaning in markdown.
  -- If somehow present, they would render as invisible/garbage anyway.
  if format_type == "italic" then
    local escaped_star_placeholder = "\001\002"
    local bold_placeholder = "\001\003"

    local result = text:gsub("\\%*", escaped_star_placeholder) -- Protect escaped asterisks
    result = result:gsub("%*%*", bold_placeholder) -- Protect bold markers
    result = strip_unescaped_pairs(result, "*") -- Strip italic markers
    result = result:gsub(bold_placeholder, "**")
    result = result:gsub(escaped_star_placeholder, "\\*")
    return result
  end

  -- For bold, make sure we're matching ** not single *
  if format_type == "bold" then
    return strip_unescaped_pairs(text, "**")
  end

  return strip_unescaped_pairs(text, pattern.wrap)
end

return M
