-- Common utilities for markdown-plus.nvim
-- Re-export facade: delegates to focused sub-modules under utils/
local M = {}

local buffer = require("markdown-plus.utils.buffer")
local text = require("markdown-plus.utils.text")
local selection = require("markdown-plus.utils.selection")
local html = require("markdown-plus.utils.html")
local element = require("markdown-plus.utils.element")

-- Buffer / cursor primitives (buffer.lua)
M.get_cursor = buffer.get_cursor
M.set_cursor = buffer.set_cursor
M.get_current_line = buffer.get_current_line
M.get_line = buffer.get_line
M.set_line = buffer.set_line
M.insert_line = buffer.insert_line
M.is_markdown_buffer = buffer.is_markdown_buffer
M.is_html_awareness_enabled = buffer.is_html_awareness_enabled
M.get_lines_in_range = buffer.get_lines_in_range
M.get_text_in_range = buffer.get_text_in_range
M.set_text_in_range = buffer.set_text_in_range
M.replace_in_line = buffer.replace_in_line
M.insert_after_cursor = buffer.insert_after_cursor
M.input = buffer.input
M.confirm = buffer.confirm
M.notify = buffer.notify

-- UTF-8 / text splitting (text.lua)
M.escape_pattern = text.escape_pattern
M.split_at_cursor = text.split_at_cursor
M.split_after_cursor = text.split_after_cursor
M.get_char_end_byte = text.get_char_end_byte

-- Visual selection (selection.lua)
M.get_visual_selection = selection.get_visual_selection
M.get_single_line_selection = selection.get_single_line_selection

-- HTML block detection (html.lua)
M.is_in_html_block = html.is_in_html_block
M.get_html_block_lines = html.get_html_block_lines

-- Element patterns and markdown builders (element.lua)
M.find_pattern_at_cursor = element.find_pattern_at_cursor
M.find_patterns_at_cursor = element.find_patterns_at_cursor
M.is_in_code_block = element.is_in_code_block
M.get_code_block_lines = element.get_code_block_lines
M.build_markdown_link = element.build_markdown_link
M.build_markdown_image = element.build_markdown_image

return M
