-- Format patterns module for markdown-plus.nvim
-- Contains pattern definitions for different formatting styles

local M = {}

---Formatting pattern definition
---@class markdown-plus.format.Pattern
---@field start string Start pattern (Lua pattern)
---@field end_pat string End pattern (Lua pattern)
---@field wrap string Wrapper string

---Formatting patterns for different styles
---@type table<string, markdown-plus.format.Pattern>
M.patterns = {
  bold = { start = "%*%*", end_pat = "%*%*", wrap = "**" },
  italic = { start = "%*", end_pat = "%*", wrap = "*" },
  strikethrough = { start = "~~", end_pat = "~~", wrap = "~~" },
  code = { start = "`", end_pat = "`", wrap = "`" },
  highlight = { start = "==", end_pat = "==", wrap = "==" },
  underline = { start = "%+%+", end_pat = "%+%+", wrap = "++" },
}

---Treesitter node types for format detection (markdown_inline parser)
---Maps format type names to treesitter node type names.
---Note: General node type constants are defined in the shared module
---`lua/markdown-plus/treesitter/init.lua` (required as `markdown-plus.treesitter`).
---These mappings are kept here to avoid circular dependencies with `markdown-plus.treesitter`.
---@type table<string, string>
M.ts_node_types = {
  bold = "strong_emphasis",
  italic = "emphasis",
  strikethrough = "strikethrough",
  code = "code_span",
  -- highlight and underline are not supported by standard markdown_inline parser
}

return M
