-- Links & References module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local smart_paste = require("markdown-plus.links.smart_paste")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Link patterns for detection
---@type table<string, string>
M.patterns = {
  inline_link = "%[(.-)%]%((.-)%)", -- [text](url)
  reference_link = "%[(.-)%]%[(.-)%]", -- [text][ref]
  reference_def = "^%[(.-)%]:%s*(.+)$", -- [ref]: url
  url = "https?://[%w-_%.%?%.:/%#%[%]@!%$&'%(%)%*%+,;=]+", -- URL pattern
}

---Extractor for inline links
---@param match string The matched link string
---@return table|nil Extracted link data or nil
local function extract_inline_link(match)
  local text, url = match:match("^%[(.-)%]%((.-)%)$")
  if text and url then
    return { type = "inline", text = text, url = url }
  end
  return nil
end

---Extractor for reference links
---@param match string The matched link string
---@return table|nil Extracted link data or nil
local function extract_reference_link(match)
  local text, ref = match:match("^%[(.-)%]%[(.-)%]$")
  if text and ref then
    return { type = "reference", text = text, ref = ref }
  end
  return nil
end

---Setup links module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
  smart_paste.setup(M.config)
end

---Enable links features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for links
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("InsertLink"),
      fn = M.insert_link,
      modes = "n",
      default_key = "<leader>ml",
      desc = "Insert markdown link",
    },
    {
      plug = keymap_helper.plug_name("SelectionToLink"),
      fn = M.selection_to_link,
      modes = "v",
      default_key = "<leader>ml",
      desc = "Convert selection to link",
    },
    {
      plug = keymap_helper.plug_name("EditLink"),
      fn = M.edit_link,
      modes = "n",
      default_key = "<leader>me",
      desc = "Edit link under cursor",
    },
    {
      plug = keymap_helper.plug_name("ConvertToReference"),
      fn = M.convert_to_reference,
      modes = "n",
      default_key = "<leader>mR",
      desc = "Convert to reference-style link",
    },
    {
      plug = keymap_helper.plug_name("ConvertToInline"),
      fn = M.convert_to_inline,
      modes = "n",
      default_key = "<leader>mI",
      desc = "Convert to inline link",
    },
    {
      plug = keymap_helper.plug_name("AutoLinkURL"),
      fn = M.auto_link_url,
      modes = "n",
      default_key = "<leader>ma",
      desc = "Convert URL to markdown link",
    },
    {
      plug = keymap_helper.plug_name("SmartPaste"),
      fn = smart_paste.smart_paste,
      modes = "n",
      default_key = "<leader>mp",
      desc = "Smart paste URL from clipboard as markdown link",
    },
  })
end

---Parse link under cursor
---@return table|nil link Link info or nil if not found
function M.get_link_at_cursor()
  return utils.find_patterns_at_cursor({
    { pattern = M.patterns.inline_link, extractor = extract_inline_link },
    { pattern = M.patterns.reference_link, extractor = extract_reference_link },
  })
end

---Build a markdown link string
---@param text string Link text
---@param url string Link URL
---@return string link The formatted link
local function build_link(text, url)
  return "[" .. text .. "](" .. url .. ")"
end

---Build a reference link string
---@param text string Link text
---@param ref string Reference ID
---@return string link The formatted reference link
local function build_reference_link(text, ref)
  return "[" .. text .. "][" .. ref .. "]"
end

---Insert a new link
---@return nil
function M.insert_link()
  local text = utils.input("Link text: ")
  if not text then
    return
  end

  local url = utils.input("URL: ")
  if not url then
    return
  end

  local link = build_link(text, url)
  utils.insert_after_cursor(link)
  utils.notify("Link inserted")
end

---Convert selection to link
---@return nil
function M.selection_to_link()
  local selection = utils.get_single_line_selection("links")
  if not selection then
    return
  end

  local url = utils.input("URL: ")
  if not url then
    return
  end

  local link = build_link(selection.text, url)
  utils.replace_in_line(selection.start_row, selection.start_col, selection.end_col, link)
  utils.set_cursor(selection.start_row, selection.start_col - 1 + #link)
  utils.notify("Link created")
end

---Edit link under cursor
---@return nil
function M.edit_link()
  local link = M.get_link_at_cursor()

  if not link then
    utils.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  if link.type == "inline" then
    local new_text = utils.input("Link text: ", link.text)
    if not new_text then
      return
    end

    local new_url = utils.input("URL: ", link.url)
    if not new_url then
      return
    end

    local new_link = build_link(new_text, new_url)
    utils.replace_in_line(link.line_num, link.start_pos, link.end_pos, new_link)
    utils.notify("Link updated")
  elseif link.type == "reference" then
    local new_text = utils.input("Link text: ", link.text)
    if not new_text then
      return
    end

    local new_ref = utils.input("Reference: ", link.ref)
    if not new_ref then
      return
    end

    local new_link = build_reference_link(new_text, new_ref)
    utils.replace_in_line(link.line_num, link.start_pos, link.end_pos, new_link)
    utils.notify("Reference link updated")
  end
end

---Find reference URL definition
---@param ref string Reference ID to find
---@return string|nil url The URL for the reference or nil
function M.find_reference_url(ref)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for _, line in ipairs(lines) do
    local found_ref, url = line:match(M.patterns.reference_def)
    if found_ref and found_ref == ref then
      return url:match("^%s*(.-)%s*$") -- trim whitespace
    end
  end

  return nil
end

---Generate a unique reference ID from link text
---@param text string Link text
---@param target_url string Target URL for the reference
---@return string|nil ref_id Unique reference ID
---@return string|nil error_msg Error message if generation failed
local function generate_unique_ref_id(text, target_url)
  local base_ref = text:lower():gsub("%s+", "-"):gsub("[^%w%-]", ""):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")

  if base_ref == "" then
    return nil, "Link text does not contain any alphanumeric characters"
  end

  local existing_url = M.find_reference_url(base_ref)
  if not existing_url or existing_url == target_url then
    return base_ref, nil
  end

  local counter = 1
  local unique_ref = base_ref .. "-" .. counter

  while M.find_reference_url(unique_ref) do
    counter = counter + 1
    unique_ref = base_ref .. "-" .. counter
    if counter > 100 then
      return nil, "Could not generate unique reference ID (too many conflicts)"
    end
  end

  return unique_ref
end

---Convert inline link to reference-style
---@return nil
function M.convert_to_reference()
  local link = M.get_link_at_cursor()

  if not link then
    utils.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  if link.type ~= "inline" then
    utils.notify("Not an inline link", vim.log.levels.WARN)
    return
  end

  local ref, err = generate_unique_ref_id(link.text, link.url)
  if not ref then
    utils.notify("Cannot generate reference: " .. err, vim.log.levels.ERROR)
    return
  end

  local existing_url = M.find_reference_url(ref)
  local reusing_existing = existing_url and existing_url == link.url

  local new_link = build_reference_link(link.text, ref)
  utils.replace_in_line(link.line_num, link.start_pos, link.end_pos, new_link)

  if not reusing_existing then
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local last_line = #lines

    if lines[last_line] ~= "" then
      vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { "" })
      last_line = last_line + 1
    end

    local ref_def = "[" .. ref .. "]: " .. link.url
    vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { ref_def })

    utils.notify("Converted to reference-style link")
  else
    utils.notify("Converted to reference-style link (reusing existing reference)")
  end
end

---Convert reference link to inline
---@return nil
function M.convert_to_inline()
  local link = M.get_link_at_cursor()

  if not link then
    utils.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  if link.type ~= "reference" then
    utils.notify("Not a reference link", vim.log.levels.WARN)
    return
  end

  local url = M.find_reference_url(link.ref)
  if not url then
    utils.notify("Reference definition not found: " .. link.ref, vim.log.levels.ERROR)
    return
  end

  local new_link = build_link(link.text, url)
  utils.replace_in_line(link.line_num, link.start_pos, link.end_pos, new_link)
  utils.notify("Converted to inline link")
end

---Auto-convert URL to link
---@return nil
function M.auto_link_url()
  local url_pattern = "(" .. M.patterns.url .. ")"

  local result = utils.find_pattern_at_cursor(url_pattern, function(match)
    -- Remove the capture group parentheses from the match
    local url = match:match("^" .. M.patterns.url .. "$")
    if url then
      return { url = url }
    end
    return nil
  end)

  if not result then
    utils.notify("No URL under cursor", vim.log.levels.WARN)
    return
  end

  local text = utils.input("Link text (empty for URL): ")
  if text == nil then
    return
  end
  if text == "" then
    text = result.url
  end

  local link = build_link(text, result.url)
  utils.replace_in_line(result.line_num, result.start_pos, result.end_pos, link)
  utils.set_cursor(result.line_num, result.start_pos - 1 + #link)
  utils.notify("URL converted to link")
end

return M
