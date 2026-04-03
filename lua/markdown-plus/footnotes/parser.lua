-- Footnote parsing facade for markdown-plus.nvim
-- Re-exports all functions from focused sub-modules for backward compatibility

local line_parser = require("markdown-plus.footnotes.line_parser")
local scanner = require("markdown-plus.footnotes.scanner")
local query = require("markdown-plus.footnotes.query")

local M = {}

-- Re-export line_parser
M.patterns = line_parser.patterns
M.parse_reference_at_cursor = line_parser.parse_reference_at_cursor
M.find_references_in_line = line_parser.find_references_in_line
M.parse_definition = line_parser.parse_definition
M.is_continuation_line = line_parser.is_continuation_line

-- Re-export scanner
M.find_all_references = scanner.find_all_references
M.find_all_definitions = scanner.find_all_definitions
M.find_definition = scanner.find_definition
M.find_references = scanner.find_references

-- Re-export query
M.get_all_footnotes = query.get_all_footnotes
M.get_next_numeric_id = query.get_next_numeric_id
M.find_footnotes_section = query.find_footnotes_section
M.get_definition_range = query.get_definition_range
M.get_definition_content = query.get_definition_content
M.get_footnote_at_cursor = query.get_footnote_at_cursor

return M
