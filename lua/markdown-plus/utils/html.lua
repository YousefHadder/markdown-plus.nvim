-- GFM HTML block detection state machine (§4.6)
local M = {}

local buffer = require("markdown-plus.utils.buffer")

---Check if a specific row is inside a GFM HTML block
---@param row? number 1-indexed row (defaults to current cursor row)
---@return boolean
function M.is_in_html_block(row)
  local target_row = row or buffer.get_cursor()[1]
  if not target_row or target_row < 1 then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local html_lines = M.get_html_block_lines(lines)
  return html_lines[target_row] == true
end

-- GFM §4.6 type-6 HTML block tags
local HTML_BLOCK_TYPE6_TAGS = {
  address = true,
  article = true,
  aside = true,
  base = true,
  basefont = true,
  blockquote = true,
  body = true,
  caption = true,
  center = true,
  col = true,
  colgroup = true,
  dd = true,
  details = true,
  dialog = true,
  dir = true,
  div = true,
  dl = true,
  dt = true,
  fieldset = true,
  figcaption = true,
  figure = true,
  footer = true,
  form = true,
  frame = true,
  frameset = true,
  h1 = true,
  h2 = true,
  h3 = true,
  h4 = true,
  h5 = true,
  h6 = true,
  head = true,
  header = true,
  hr = true,
  html = true,
  iframe = true,
  legend = true,
  li = true,
  link = true,
  main = true,
  menu = true,
  menuitem = true,
  nav = true,
  noframes = true,
  ol = true,
  optgroup = true,
  option = true,
  p = true,
  param = true,
  search = true,
  section = true,
  summary = true,
  table = true,
  tbody = true,
  td = true,
  tfoot = true,
  th = true,
  thead = true,
  title = true,
  tr = true,
  track = true,
  ul = true,
}

---Build a set of line numbers inside GFM HTML blocks (§4.6).
---Handles all 7 HTML block types:
---1) <script|pre|style>, 2) <!-- -->, 3) <? ?>, 4) <!X...>, 5) <![CDATA[ ]]>,
---6) block tags (e.g. <div>), 7) standalone open/close tags.
---@param lines string[] All lines to scan
---@return table<number, boolean> Set of 1-indexed line numbers inside HTML blocks
function M.get_html_block_lines(lines)
  local html_lines = {}
  local mode = nil ---@type "type1"|"comment"|"pi"|"declaration"|"cdata"|"type6"|"type7"|nil
  local type1_tag = nil ---@type string|nil

  for i, line in ipairs(lines) do
    local handled_existing_mode = false

    if mode == "type6" or mode == "type7" then
      handled_existing_mode = true
      if line:match("^%s*$") then
        mode = nil
      else
        html_lines[i] = true
      end
    elseif mode == "type1" then
      handled_existing_mode = true
      html_lines[i] = true
      if type1_tag and line:lower():find("</" .. type1_tag .. "%s*>") then
        mode = nil
        type1_tag = nil
      end
    elseif mode == "comment" then
      handled_existing_mode = true
      html_lines[i] = true
      if line:find("%-%->") then
        mode = nil
      end
    elseif mode == "pi" then
      handled_existing_mode = true
      html_lines[i] = true
      if line:find("%?>") then
        mode = nil
      end
    elseif mode == "declaration" then
      handled_existing_mode = true
      html_lines[i] = true
      if line:find(">", 1, true) then
        mode = nil
      end
    elseif mode == "cdata" then
      handled_existing_mode = true
      html_lines[i] = true
      if line:find("%]%]>") then
        mode = nil
      end
    end

    if not handled_existing_mode then
      -- Type 1: <script>, <pre>, <style>
      local open_tag = line:match("^%s*<([A-Za-z]+)[%s>/]")
      local handled_new_mode = false
      if open_tag then
        local tag = open_tag:lower()
        if tag == "script" or tag == "pre" or tag == "style" then
          html_lines[i] = true
          if not line:lower():find("</" .. tag .. "%s*>") then
            mode = "type1"
            type1_tag = tag
          end
          handled_new_mode = true
        end
      end

      if not handled_new_mode then
        -- Type 2: HTML comments
        if line:match("^%s*<!%-%-") then
          html_lines[i] = true
          if not line:find("%-%->") then
            mode = "comment"
          end
        -- Type 3: Processing instructions
        elseif line:match("^%s*<%?") then
          html_lines[i] = true
          if not line:find("%?>") then
            mode = "pi"
          end
        -- Type 4: Declarations (e.g. <!DOCTYPE html>)
        elseif line:match("^%s*<!%u") then
          html_lines[i] = true
          if not line:find(">", 1, true) then
            mode = "declaration"
          end
        -- Type 5: CDATA
        elseif line:match("^%s*<!%[CDATA%[") then
          html_lines[i] = true
          if not line:find("%]%]>") then
            mode = "cdata"
          end
        else
          -- Type 6: Block tag starts (ends on first following blank line)
          local block_tag = line:match("^%s*</?([A-Za-z][A-Za-z0-9%-]*)[%s>/]")
          if block_tag and HTML_BLOCK_TYPE6_TAGS[block_tag:lower()] then
            html_lines[i] = true
            mode = "type6"
          else
            -- Type 7: Standalone open/close tag lines (ends on first following blank line)
            local standalone_tag = line:match("^%s*<([A-Za-z][A-Za-z0-9%-]*)%f[%s/>][^>]*>%s*$")
              or line:match("^%s*</([A-Za-z][A-Za-z0-9%-]*)%s*>%s*$")
            if standalone_tag then
              local tag = standalone_tag:lower()
              if tag ~= "script" and tag ~= "pre" and tag ~= "style" and not HTML_BLOCK_TYPE6_TAGS[tag] then
                html_lines[i] = true
                mode = "type7"
              end
            end
          end
        end
      end
    end
  end

  return html_lines
end

return M
