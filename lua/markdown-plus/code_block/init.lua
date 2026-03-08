local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local parser = require("markdown-plus.code_block.parser")
local navigation = require("markdown-plus.code_block.navigation")

local M = {}

local ESC = "\027"
local CUSTOM_LANGUAGE_LABEL = "Custom..."
local DEFAULT_LANGUAGES = {
  "lua",
  "python",
  "javascript",
  "typescript",
  "bash",
  "json",
  "yaml",
  "markdown",
}

---@type markdown-plus.InternalConfig
M.config = {}

---@return string[]
local function get_languages()
  local configured = M.config.code_block and M.config.code_block.languages
  if type(configured) == "table" and #configured > 0 then
    return configured
  end
  return DEFAULT_LANGUAGES
end

---@return string
local function get_fence_delimiter()
  local style = M.config.code_block and M.config.code_block.fence_style or "backtick"
  return style == "tilde" and "~~~" or "```"
end

---@param current_language string
---@param on_selected fun(language: string|nil)
---@return nil
local function select_language(current_language, on_selected)
  local options = vim.deepcopy(get_languages())
  table.insert(options, CUSTOM_LANGUAGE_LABEL)

  vim.ui.select(options, { prompt = "Code block language:" }, function(choice)
    if not choice then
      on_selected(nil)
      return
    end

    if choice == CUSTOM_LANGUAGE_LABEL then
      local custom = utils.input("Code block language: ", current_language)
      if not custom then
        on_selected(nil)
        return
      end
      on_selected(vim.trim(custom))
      return
    end

    on_selected(choice)
  end)
end

---@param fence string
---@param language string
---@return string
local function opening_fence_line(fence, language)
  if language ~= "" then
    return fence .. language
  end
  return fence
end

---Setup code block module
---@param config markdown-plus.InternalConfig
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable code block features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  M.setup_keymaps()
end

---Insert a fenced code block below cursor with selected language
---@return nil
function M.insert_with_language()
  select_language("", function(language)
    if language == nil then
      return
    end

    local fence = get_fence_delimiter()
    local opening = opening_fence_line(fence, language)
    local row = utils.get_cursor()[1]

    vim.api.nvim_buf_set_lines(0, row, row, false, { opening, "", fence })
    utils.set_cursor(row + 1, 0)
  end)
end

---Wrap visual selection in a fenced code block with selected language
---@return nil
function M.wrap_selection()
  local selection = utils.get_visual_selection(false)
  local start_row = math.min(selection.start_row, selection.end_row)
  local end_row = math.max(selection.start_row, selection.end_row)
  vim.cmd("normal! " .. ESC)

  select_language("", function(language)
    if language == nil then
      return
    end

    local fence = get_fence_delimiter()
    local opening = opening_fence_line(fence, language)

    vim.api.nvim_buf_set_lines(0, start_row - 1, start_row - 1, false, { opening })
    vim.api.nvim_buf_set_lines(0, end_row + 1, end_row + 1, false, { fence })
  end)
end

---Change language info string on the code block under cursor
---@return nil
function M.change_language()
  local block = parser.find_block_at_cursor()
  if not block then
    utils.notify("No code block under cursor", vim.log.levels.WARN)
    return
  end

  select_language(block.language or "", function(language)
    if language == nil then
      return
    end

    local fence = string.rep(block.fence_char, block.fence_length)
    local new_line = block.opening_indent .. opening_fence_line(fence, language)
    utils.set_line(block.start_line, new_line)
  end)
end

---Toggle code block fence style between backticks and tildes
---@return nil
function M.toggle_fence_style()
  local block = parser.find_block_at_cursor()
  if not block then
    utils.notify("No code block under cursor", vim.log.levels.WARN)
    return
  end

  local target_char = block.fence_char == "`" and "~" or "`"
  local opening_fence = string.rep(target_char, block.fence_length)
  local new_opening = block.opening_indent .. opening_fence
  if block.info_string ~= "" then
    new_opening = new_opening .. block.info_string
  end
  utils.set_line(block.start_line, new_opening)

  if block.is_closed then
    local closing_fence = string.rep(target_char, block.closing_fence_length)
    utils.set_line(block.end_line, block.closing_indent .. closing_fence)
  end
end

---Set up keymaps for code block feature
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("CodeBlockInsert"),
      fn = {
        M.insert_with_language,
        M.wrap_selection,
      },
      modes = { "n", "x" },
      default_key = { "<localleader>mc", "<localleader>mc" },
      desc = "Insert/wrap fenced code block with language",
    },
    {
      -- Backward-compatible visual mapping name previously exposed by format module
      plug = keymap_helper.plug_name("CodeBlock"),
      fn = M.wrap_selection,
      modes = "x",
      desc = "Wrap visual selection in fenced code block",
    },
    {
      plug = keymap_helper.plug_name("CodeBlockNext"),
      fn = navigation.next_block,
      modes = "n",
      default_key = "]b",
      desc = "Jump to next fenced code block",
    },
    {
      plug = keymap_helper.plug_name("CodeBlockPrev"),
      fn = navigation.prev_block,
      modes = "n",
      default_key = "[b",
      desc = "Jump to previous fenced code block",
    },
    {
      plug = keymap_helper.plug_name("CodeBlockChangeLanguage"),
      fn = M.change_language,
      modes = "n",
      default_key = "<localleader>mC",
      desc = "Change language of fenced code block",
    },
    {
      plug = keymap_helper.plug_name("CodeBlockToggleFence"),
      fn = M.toggle_fence_style,
      modes = "n",
      desc = "Toggle code block fence style",
    },
  })
end

M.find_block_at_cursor = parser.find_block_at_cursor
M.find_all_blocks = parser.find_all_blocks
M.next_block = navigation.next_block
M.prev_block = navigation.prev_block

return M
