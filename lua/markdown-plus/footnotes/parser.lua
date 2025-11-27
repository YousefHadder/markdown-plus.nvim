-- Footnote parsing module for markdown-plus.nvim
-- Handles pattern matching and detection of footnote references and definitions
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
  -- Matches fenced code block delimiter (``` or ~~~)
  code_fence = "^%s*```",
  code_fence_tilde = "^%s*~~~",
}

---Check if a line is a code fence (``` or ~~~)
---@param line string The line content
---@return boolean is_fence True if line is a code fence
local function is_code_fence(line)
  return line:match(M.patterns.code_fence) ~= nil or line:match(M.patterns.code_fence_tilde) ~= nil
end

---Build a set of line numbers that are inside code blocks
---@param lines string[] All lines in buffer
---@return table<number, boolean> Set of line numbers inside code blocks
local function get_code_block_lines(lines)
  local in_code_block = false
  local code_lines = {}

  for line_num, line in ipairs(lines) do
    if is_code_fence(line) then
      if in_code_block then
        -- Closing fence - this line is still part of code block
        code_lines[line_num] = true
        in_code_block = false
      else
        -- Opening fence
        code_lines[line_num] = true
        in_code_block = true
      end
    elseif in_code_block then
      code_lines[line_num] = true
    end
  end

  return code_lines
end

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

---Find all footnote references in a buffer
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@return markdown-plus.footnotes.Reference[] references All references found
function M.find_all_references(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local all_refs = {}
  local code_lines = get_code_block_lines(lines)

  for line_num, line in ipairs(lines) do
    -- Skip lines inside code blocks
    if not code_lines[line_num] then
      local refs = M.find_references_in_line(line, line_num)
      for _, ref in ipairs(refs) do
        table.insert(all_refs, ref)
      end
    end
  end

  return all_refs
end

---Find all footnote definitions in a buffer
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@return markdown-plus.footnotes.Definition[] definitions All definitions found
function M.find_all_definitions(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local definitions = {}
  local code_lines = get_code_block_lines(lines)

  local i = 1
  while i <= #lines do
    -- Skip lines inside code blocks
    if code_lines[i] then
      i = i + 1
    else
      local def = M.parse_definition(lines[i])
      if def then
        local end_line = i

        -- Check for multi-line content (also skip if continuation is in code block)
        local j = i + 1
        while j <= #lines and not code_lines[j] do
          local is_cont, _ = M.is_continuation_line(lines[j])
          if is_cont then
            end_line = j
            j = j + 1
          else
            break
          end
        end

        table.insert(definitions, {
          id = def.id,
          content = def.content,
          line_num = i,
          end_line = end_line,
        })

        i = end_line + 1
      else
        i = i + 1
      end
    end
  end

  return definitions
end

---Find a specific footnote definition by ID
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param id string Footnote ID to find
---@return markdown-plus.footnotes.Definition|nil definition Definition info or nil if not found
function M.find_definition(bufnr, id)
  local definitions = M.find_all_definitions(bufnr)
  for _, def in ipairs(definitions) do
    if def.id == id then
      return def
    end
  end
  return nil
end

---Find all references to a specific footnote ID
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param id string Footnote ID to find
---@return markdown-plus.footnotes.Reference[] references All references to this ID
function M.find_references(bufnr, id)
  local all_refs = M.find_all_references(bufnr)
  local matching_refs = {}

  for _, ref in ipairs(all_refs) do
    if ref.id == id then
      table.insert(matching_refs, ref)
    end
  end

  return matching_refs
end

---Get all footnotes with their references and definitions
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@return markdown-plus.footnotes.Footnote[] footnotes All footnotes
function M.get_all_footnotes(bufnr)
  local all_refs = M.find_all_references(bufnr)
  local all_defs = M.find_all_definitions(bufnr)

  -- Build a map of ID -> footnote
  local footnotes_map = {}

  -- Add all definitions
  for _, def in ipairs(all_defs) do
    footnotes_map[def.id] = {
      id = def.id,
      definition = def,
      references = {},
    }
  end

  -- Add all references
  for _, ref in ipairs(all_refs) do
    if not footnotes_map[ref.id] then
      -- Orphan reference (no definition)
      footnotes_map[ref.id] = {
        id = ref.id,
        definition = nil,
        references = {},
      }
    end
    table.insert(footnotes_map[ref.id].references, ref)
  end

  -- Convert map to sorted array
  local footnotes = {}
  for _, fn in pairs(footnotes_map) do
    table.insert(footnotes, fn)
  end

  -- Sort by first appearance (definition line or first reference)
  table.sort(footnotes, function(a, b)
    local a_line = a.definition and a.definition.line_num or (a.references[1] and a.references[1].line_num or 0)
    local b_line = b.definition and b.definition.line_num or (b.references[1] and b.references[1].line_num or 0)
    return a_line < b_line
  end)

  return footnotes
end

---Get the next available numeric footnote ID
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@return string next_id Next available numeric ID as string
function M.get_next_numeric_id(bufnr)
  local footnotes = M.get_all_footnotes(bufnr)

  -- Find the highest numeric ID currently in use
  local max_num = 0
  for _, fn in ipairs(footnotes) do
    local num = tonumber(fn.id)
    if num and num > max_num then
      max_num = num
    end
  end

  -- Return the next number after the highest
  return tostring(max_num + 1)
end

---Find the footnotes section header line
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param section_header? string Header text to match (default: "Footnotes")
---@return number|nil line_num Line number of section header, or nil if not found
function M.find_footnotes_section(bufnr, section_header)
  bufnr = bufnr or 0
  section_header = section_header or "Footnotes"
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local pattern = "^##%s+" .. vim.pesc(section_header) .. "%s*$"

  for line_num, line in ipairs(lines) do
    if line:match(pattern) then
      return line_num
    end
  end

  return nil
end

---Get the full range of a multi-line footnote definition
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param def_line_num number Line number of the definition start
---@return number|nil start_line Start line of definition, or nil if not a definition
---@return number|nil end_line End line of definition
function M.get_definition_range(bufnr, def_line_num)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if def_line_num < 1 or def_line_num > #lines then
    return nil, nil
  end

  -- Verify this is a definition line
  local def = M.parse_definition(lines[def_line_num])
  if not def then
    return nil, nil
  end

  local end_line = def_line_num

  -- Check for multi-line content
  local j = def_line_num + 1
  while j <= #lines do
    local is_cont, _ = M.is_continuation_line(lines[j])
    if is_cont then
      end_line = j
      j = j + 1
    else
      break
    end
  end

  return def_line_num, end_line
end

---Get the full content of a multi-line footnote definition
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param def_line_num number Line number of the definition start
---@return string|nil content Full content of the definition, or nil if not a definition
function M.get_definition_content(bufnr, def_line_num)
  bufnr = bufnr or 0
  local start_line, end_line = M.get_definition_range(bufnr, def_line_num)
  if not start_line then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  -- First line: extract content after [^id]:
  local first_line = lines[1]
  local _, content = first_line:match(M.patterns.definition)
  local result = { content or "" }

  -- Subsequent lines: keep as-is (with indentation for multi-line)
  for i = 2, #lines do
    table.insert(result, lines[i])
  end

  return table.concat(result, "\n")
end

---Check if cursor is on a footnote reference or definition
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@param line_num? number Line number (1-indexed, default: current line)
---@param col? number Column (1-indexed, default: current column)
---@return {type: "reference"|"definition", id: string, line_num: number}|nil result Info about footnote at cursor
function M.get_footnote_at_cursor(bufnr, line_num, col)
  bufnr = bufnr or 0

  if not line_num or not col then
    local cursor = vim.api.nvim_win_get_cursor(0)
    line_num = line_num or cursor[1]
    col = col or cursor[2] + 1 -- Convert to 1-indexed
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Check if cursor is inside a code block
  local code_lines = get_code_block_lines(lines)
  if code_lines[line_num] then
    return nil
  end

  local line = lines[line_num]
  if not line then
    return nil
  end

  -- Check if it's a definition line
  local def = M.parse_definition(line)
  if def then
    return {
      type = "definition",
      id = def.id,
      line_num = line_num,
    }
  end

  -- Check if cursor is on a reference
  local ref = M.parse_reference_at_cursor(line, col)
  if ref then
    return {
      type = "reference",
      id = ref.id,
      line_num = line_num,
    }
  end

  return nil
end

return M
