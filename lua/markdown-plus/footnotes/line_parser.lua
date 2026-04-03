-- Line-level footnote parsing for markdown-plus.nvim
-- Handles pattern matching and detection of individual footnote references and definitions

local M = {}

---@class markdown-plus.footnotes.Reference
---@field id string Footnote ID
---@field start_col number Start column (1-indexed)
---@field end_col number End column (1-indexed)
---@field line_num number Line number (1-indexed)

---@class markdown-plus.footnotes.Definition
---@field id string Footnote ID
---@field content string First line of content (after [^id]: )
---@field line_num number Line number (1-indexed)
---@field end_line number End line of multi-line definition (1-indexed)

---@class markdown-plus.footnotes.Footnote
---@field id string Footnote ID
---@field definition markdown-plus.footnotes.Definition|nil Definition info (nil if orphan reference)
---@field references markdown-plus.footnotes.Reference[] All references to this footnote

-- Patterns for footnote detection
-- Reference: [^id] where id is alphanumeric, hyphen, or underscore
-- Definition: [^id]: at line start (with optional leading whitespace)
M.patterns = {
  -- Matches [^id] - captures the ID
  reference = "%[%^([%w%-_]+)%]",
  -- Matches [^id]: at start of line - captures ID and content
  definition = "^%s*%[%^([%w%-_]+)%]:%s*(.*)$",
  -- Matches continuation line (4+ spaces or tab)
  continuation = "^%s%s%s%s+(.*)$",
  -- Matches the footnotes section header
  section_header = "^##%s+",
}

---Parse a footnote reference at a specific position in a line
---@param line string The line content
---@param col number Cursor column (1-indexed)
---@return markdown-plus.footnotes.Reference|nil reference Reference info or nil if not found
function M.parse_reference_at_cursor(line, col)
  -- Find all references in the line
  local refs = M.find_references_in_line(line)

  -- Check if cursor is within any reference
  for _, ref in ipairs(refs) do
    if col >= ref.start_col and col <= ref.end_col then
      return ref
    end
  end

  return nil
end

---Find all footnote references in a line
---@param line string The line content
---@param line_num? number Optional line number to include in results
---@return markdown-plus.footnotes.Reference[] references List of references found
function M.find_references_in_line(line, line_num)
  local refs = {}

  -- Build a set of character positions that are inside inline code
  local in_code = {}
  local i = 1
  while i <= #line do
    -- Check for backtick
    if line:sub(i, i) == "`" then
      -- Count consecutive backticks (for `` code spans)
      local backtick_start = i
      local backtick_count = 0
      while i <= #line and line:sub(i, i) == "`" do
        backtick_count = backtick_count + 1
        i = i + 1
      end
      -- Find matching closing backticks
      local close_pattern = string.rep("`", backtick_count)
      local close_start = line:find(close_pattern, i, true)
      if close_start then
        -- Mark all positions between opening and closing as in_code
        for pos = backtick_start, close_start + backtick_count - 1 do
          in_code[pos] = true
        end
        i = close_start + backtick_count
      end
    else
      i = i + 1
    end
  end

  local search_start = 1

  while true do
    -- Find the next [^ pattern
    local bracket_start = line:find("%[%^", search_start)
    if not bracket_start then
      break
    end

    -- Skip if inside inline code
    if in_code[bracket_start] then
      search_start = bracket_start + 2
    else
      -- Try to match the full reference pattern starting here
      local match_start, match_end, id = line:find("%[%^([%w%-_]+)%]", bracket_start)

      if match_start == bracket_start and id then
        -- Check if this is actually a definition (followed by :)
        -- Definitions look like [^id]: so we skip those
        local next_char = line:sub(match_end + 1, match_end + 1)
        if next_char ~= ":" then
          table.insert(refs, {
            id = id,
            start_col = match_start,
            end_col = match_end,
            line_num = line_num or 0,
          })
        end
        search_start = match_end + 1
      else
        -- Move past this [^ to continue searching
        search_start = bracket_start + 2
      end
    end
  end

  return refs
end

---Parse a footnote definition line
---@param line string The line content
---@return {id: string, content: string}|nil definition Definition info or nil if not a definition
function M.parse_definition(line)
  local id, content = line:match(M.patterns.definition)
  if id then
    return {
      id = id,
      content = content or "",
    }
  end
  return nil
end

---Check if a line is a continuation of a multi-line footnote definition
---@param line string The line content
---@return boolean is_continuation True if line is a continuation
---@return string|nil content The continuation content (without leading spaces)
function M.is_continuation_line(line)
  -- Empty line is NOT a continuation by itself - ends the definition
  if line == "" then
    return false, nil
  end

  -- Line with 4+ leading spaces is a continuation
  local content = line:match(M.patterns.continuation)
  if content then
    return true, content
  end

  -- Tab-indented content
  if line:match("^\t") then
    return true, line:sub(2)
  end

  return false, nil
end

return M
