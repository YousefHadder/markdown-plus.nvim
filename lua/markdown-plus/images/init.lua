-- Images module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Image patterns for detection
---@type table<string, string>
M.patterns = {
  image_with_title = '%!%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)', -- ![alt](url "title")
  image_link = "%!%[([^%]]*)%]%(([^%)]+)%)", -- ![alt](url)
  regular_link = "%[([^%]]*)%]%(([^%)]+)%)", -- [text](url)
}

---Extractor for image with title
---@param match string The matched image string
---@return table|nil Extracted image data or nil
local function extract_image_with_title(match)
  local alt, url, title = match:match('^%!%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)$')
  if alt and url and title then
    return { type = "image_with_title", alt = alt, url = url, title = title }
  end
  return nil
end

---Extractor for basic image
---@param match string The matched image string
---@return table|nil Extracted image data or nil
local function extract_image(match)
  local alt, url = match:match("^%!%[([^%]]*)%]%(([^%)]+)%)$")
  if alt and url then
    -- Check if this is actually an image with title that we missed
    local url_trimmed = url:match("^%s*(.-)%s*$")
    local url_part, title_part = url_trimmed:match('^([^%s]+)%s+"([^"]+)"$')
    if url_part and title_part then
      return { type = "image_with_title", alt = alt, url = url_part, title = title_part }
    end
    return { type = "image", alt = alt, url = url_trimmed }
  end
  return nil
end

---Extractor for regular link (used in toggle)
---@param match string The matched link string
---@return table|nil Extracted link data or nil
local function extract_regular_link(match)
  -- Try to match link with title first
  local text, url, title = match:match('^%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)$')
  if text and url and title then
    return { type = "link", text = text, url = url, title = title }
  end

  -- Try basic link pattern
  text, url = match:match("^%[([^%]]*)%]%(([^%)]+)%)$")
  if text and url then
    local url_trimmed = url:match("^%s*(.-)%s*$")
    local url_part, title_part = url_trimmed:match('^([^%s]+)%s+"([^"]+)"$')
    if url_part and title_part then
      return { type = "link", text = text, url = url_part, title = title_part }
    end
    return { type = "link", text = text, url = url_trimmed }
  end
  return nil
end

---Setup images module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable images features for current buffer
---@return nil
function M.enable()
  -- Set up keymaps
  M.setup_keymaps()
end

---Set up keymaps for images
---@return nil
function M.setup_keymaps()
  keymap_helper.setup_keymaps(M.config, {
    {
      plug = keymap_helper.plug_name("InsertImage"),
      fn = M.insert_image,
      modes = "n",
      default_key = "<leader>mL",
      desc = "Insert markdown image",
    },
    {
      plug = keymap_helper.plug_name("SelectionToImage"),
      fn = M.selection_to_image,
      modes = "v",
      default_key = "<leader>mL",
      desc = "Convert selection to image",
    },
    {
      plug = keymap_helper.plug_name("EditImage"),
      fn = M.edit_image,
      modes = "n",
      default_key = "<leader>mE",
      desc = "Edit image under cursor",
    },
    {
      plug = keymap_helper.plug_name("ToggleImageLink"),
      fn = M.toggle_image_link,
      modes = "n",
      default_key = "<leader>mA",
      desc = "Toggle between link and image",
    },
  })
end

---Parse image link under cursor
---@return table|nil image Image info table or nil if not found
function M.get_image_at_cursor()
  return utils.find_patterns_at_cursor({
    { pattern = M.patterns.image_with_title, extractor = extract_image_with_title },
    { pattern = M.patterns.image_link, extractor = extract_image },
  })
end

---Build an image markdown string
---@param alt string Alt text
---@param url string Image URL
---@param title? string Optional title
---@return string image The formatted image
local function build_image(alt, url, title)
  if title and title ~= "" then
    return string.format('![%s](%s "%s")', alt, url, title)
  else
    return string.format("![%s](%s)", alt, url)
  end
end

---Build a regular link markdown string
---@param text string Link text
---@param url string Link URL
---@param title? string Optional title
---@return string link The formatted link
local function build_link(text, url, title)
  if title and title ~= "" then
    return string.format('[%s](%s "%s")', text, url, title)
  else
    return string.format("[%s](%s)", text, url)
  end
end

---Insert a new image link
---@return nil
function M.insert_image()
  local alt = utils.input("Alt text: ", "")
  if alt == nil then
    return
  end

  local url = utils.input("URL: ")
  if url == nil then
    return
  end

  local title = utils.input("Title (optional): ", "")

  local image = build_image(alt, url, title)
  utils.insert_after_cursor(image)
  utils.notify("Image inserted")
end

---Convert selection to image link
---@return nil
function M.selection_to_image()
  local selection = utils.get_single_line_selection("images")
  if not selection then
    return
  end

  local url = utils.input("URL: ")
  if url == nil then
    return
  end

  local title = utils.input("Title (optional): ", "")

  local image = build_image(selection.text, url, title)
  utils.replace_in_line(selection.start_row, selection.start_col, selection.end_col, image)
  utils.set_cursor(selection.start_row, selection.start_col - 1 + #image)
  utils.notify("Image created")
end

---Edit image under cursor
---@return nil
function M.edit_image()
  local image = M.get_image_at_cursor()

  if not image then
    utils.notify("No image under cursor", vim.log.levels.WARN)
    return
  end

  local new_alt = utils.input("Alt text: ", image.alt or "")
  if new_alt == nil then
    return
  end

  local new_url = utils.input("URL: ", image.url)
  if new_url == nil then
    return
  end

  local default_title = image.title or ""
  local new_title = utils.input("Title (optional): ", default_title)

  local new_image = build_image(new_alt, new_url, new_title)
  utils.replace_in_line(image.line_num, image.start_pos, image.end_pos, new_image)
  utils.notify("Image updated")
end

---Toggle between regular link and image link
---@return nil
function M.toggle_image_link()
  -- First, check if cursor is on an image link
  local image = M.get_image_at_cursor()
  if image then
    -- Convert image to regular link (remove the !)
    local regular_link = build_link(image.alt, image.url, image.title)
    utils.replace_in_line(image.line_num, image.start_pos, image.end_pos, regular_link)
    utils.notify("Converted to regular link")
    return
  end

  -- Check if cursor is on a regular link
  local link = utils.find_pattern_at_cursor(M.patterns.regular_link, extract_regular_link)
  if link then
    -- Convert regular link to image (add !)
    local image_link = build_image(link.text, link.url, link.title)
    utils.replace_in_line(link.line_num, link.start_pos, link.end_pos, image_link)
    utils.notify("Converted to image link")
    return
  end

  utils.notify("No link or image under cursor", vim.log.levels.WARN)
end

return M
