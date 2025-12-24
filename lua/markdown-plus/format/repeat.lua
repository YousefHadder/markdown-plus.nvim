-- Dot-repeat support module for markdown-plus.nvim format feature
-- Handles repeat.vim integration and operatorfunc-based repeat

local M = {}

-- Forward reference to toggle module (set via init)
local toggle_module = nil

---Set the toggle module reference
---@param toggle table The toggle module
function M.set_toggle_module(toggle)
  toggle_module = toggle
end

---State for dot-repeat operations
M._repeat_state = {
  format_type = nil,
}

---Register a mapping for dot-repeat support (for use with repeat.vim if available)
---@param plug string The plug mapping to register (e.g., "<Plug>(MarkdownPlusBold)")
---@return nil
function M.register_repeat(plug)
  if not plug then
    return
  end

  -- Check if repeat.vim is available
  local has_repeat = vim.fn.exists("*repeat#set") == 1
  if not has_repeat then
    return
  end

  -- Schedule the repeat registration to happen after current operation completes
  vim.schedule(function()
    local termcodes = vim.api.nvim_replace_termcodes(plug, true, true, true)
    vim.fn["repeat#set"](termcodes)
  end)
end

---Operatorfunc callback for dot-repeat support
---@return nil
function M._format_operatorfunc()
  if not M._repeat_state.format_type or not toggle_module then
    return
  end

  -- Apply the formatting operation on the range
  toggle_module.toggle_format_word(M._repeat_state.format_type)
end

---Operatorfunc callback for clear formatting
---@return nil
function M._clear_operatorfunc()
  if not toggle_module then
    return
  end
  toggle_module.clear_formatting_word()
end

---Wrapper to make formatting dot-repeatable using operatorfunc
---@param format_type string The type of formatting to apply
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._toggle_format_with_repeat(format_type, plug)
  -- Save state for repeat
  M._repeat_state.format_type = format_type

  -- Set operatorfunc for the g@ operator
  vim.o.operatorfunc = "v:lua.require'markdown-plus.format.repeat'._format_operatorfunc"

  -- Register with repeat.vim if available
  if plug then
    M.register_repeat(plug)
  end

  -- Return g@l for linewise operation (operatorfunc will handle word detection)
  return "g@l"
end

---Wrapper to make clear formatting dot-repeatable
---@param plug string? Optional plug mapping for repeat.vim support
---@return string The operator sequence for expr mapping
function M._clear_with_repeat(plug)
  -- Set operatorfunc for the g@ operator
  vim.o.operatorfunc = "v:lua.require'markdown-plus.format.repeat'._clear_operatorfunc"

  -- Register with repeat.vim if available
  if plug then
    M.register_repeat(plug)
  end

  -- Return g@l for linewise operation (operatorfunc will handle word detection)
  return "g@l"
end

return M
