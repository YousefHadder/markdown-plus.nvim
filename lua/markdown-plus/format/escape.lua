local M = {}

local ASCII_ESCAPABLE_PUNCTUATION = [[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]]

---@param char string
---@return boolean
local function is_escapable_punctuation(char)
  return #char == 1 and ASCII_ESCAPABLE_PUNCTUATION:find(char, 1, true) ~= nil
end

---Escape markdown punctuation characters using GFM backslash escapes
---@param text string
---@return string
function M.escape_markdown(text)
  local out = {}
  local i = 1

  while i <= #text do
    local char = text:sub(i, i)
    local next_char = i < #text and text:sub(i + 1, i + 1) or ""

    if char == "\\" and is_escapable_punctuation(next_char) then
      table.insert(out, "\\")
      table.insert(out, next_char)
      i = i + 2
    elseif is_escapable_punctuation(char) then
      table.insert(out, "\\" .. char)
      i = i + 1
    else
      table.insert(out, char)
      i = i + 1
    end
  end

  return table.concat(out)
end

---Remove one level of markdown backslash escaping for punctuation characters
---@param text string
---@return string
function M.unescape_markdown(text)
  local out = {}
  local i = 1

  while i <= #text do
    local char = text:sub(i, i)
    local next_char = i < #text and text:sub(i + 1, i + 1) or ""

    if char == "\\" and is_escapable_punctuation(next_char) then
      table.insert(out, next_char)
      i = i + 2
    else
      table.insert(out, char)
      i = i + 1
    end
  end

  return table.concat(out)
end

---Check whether text contains markdown backslash escapes for punctuation
---@param text string
---@return boolean
function M.has_escaped_markdown(text)
  local i = 1
  while i < #text do
    if text:sub(i, i) == "\\" and is_escapable_punctuation(text:sub(i + 1, i + 1)) then
      return true
    end
    i = i + 1
  end

  return false
end

return M
