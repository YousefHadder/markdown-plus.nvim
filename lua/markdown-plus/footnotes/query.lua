-- High-level footnote query and aggregation for markdown-plus.nvim
-- Provides composite operations that combine scanning and line parsing

local utils = require("markdown-plus.utils")
local line_parser = require("markdown-plus.footnotes.line_parser")
local scanner = require("markdown-plus.footnotes.scanner")

local M = {}

---Returns a set of line numbers that are inside code blocks
---Uses regex for full-buffer scanning (faster than TS tree walk in testing)
---@param lines string[] All lines in buffer
---@return table<number, boolean> Set of line numbers inside code blocks
local function get_code_block_lines(lines)
  return utils.get_code_block_lines(lines)
end

---Get all footnotes with their references and definitions
---@param bufnr? number Buffer number (0 or nil for current buffer)
---@return markdown-plus.footnotes.Footnote[] footnotes All footnotes
function M.get_all_footnotes(bufnr)
  local all_refs = scanner.find_all_references(bufnr)
  local all_defs = scanner.find_all_definitions(bufnr)

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
  local def = line_parser.parse_definition(lines[def_line_num])
  if not def then
    return nil, nil
  end

  local end_line = def_line_num

  -- Check for multi-line content
  local j = def_line_num + 1
  while j <= #lines do
    local is_cont, _ = line_parser.is_continuation_line(lines[j])
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
  local _, content = first_line:match(line_parser.patterns.definition)
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
  local def = line_parser.parse_definition(line)
  if def then
    return {
      type = "definition",
      id = def.id,
      line_num = line_num,
    }
  end

  -- Check if cursor is on a reference
  local ref = line_parser.parse_reference_at_cursor(line, col)
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
