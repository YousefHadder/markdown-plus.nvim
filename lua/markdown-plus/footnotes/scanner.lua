-- Buffer-level footnote scanning for markdown-plus.nvim
-- Scans entire buffers for footnote references and definitions

local utils = require("markdown-plus.utils")
local line_parser = require("markdown-plus.footnotes.line_parser")

local M = {}

---Returns a set of line numbers that are inside code blocks
---Uses regex for full-buffer scanning (faster than TS tree walk in testing)
---@param lines string[] All lines in buffer
---@return table<number, boolean> Set of line numbers inside code blocks
local function get_code_block_lines(lines)
  return utils.get_code_block_lines(lines)
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
      local refs = line_parser.find_references_in_line(line, line_num)
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
      local def = line_parser.parse_definition(lines[i])
      if def then
        local end_line = i

        -- Check for multi-line content (also skip if continuation is in code block)
        local j = i + 1
        while j <= #lines and not code_lines[j] do
          local is_cont, _ = line_parser.is_continuation_line(lines[j])
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

return M
