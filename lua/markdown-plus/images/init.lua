-- Images module for markdown-plus.nvim
local utils = require("markdown-plus.utils")
local keymap_helper = require("markdown-plus.keymap_helper")
local M = {}

---@type markdown-plus.InternalConfig
M.config = {}

---Image patterns for detection
---@type table<string, string>
M.patterns = {
  image_link = "%!%[([^%]]*)%]%(([^%)]+)%)", -- ![alt](url)
  image_with_title = '%!%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)', -- ![alt](url "title")
  regular_link = "%[([^%]]*)%]%(([^%)]+)%)", -- [text](url)
}

---Setup images module
---@param config markdown-plus.InternalConfig Plugin configuration
---@return nil
function M.setup(config)
  M.config = config or {}
end

---Enable images features for current buffer
---@return nil
function M.enable()
  if not utils.is_markdown_buffer() then
    return
  end

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
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2] -- 0-indexed column

  -- Try to match image with title first (more specific pattern)
  local init = 1
  while true do
    local img_start, img_end = line:find(M.patterns.image_with_title, init)
    if not img_start then
      break
    end

    -- Check if cursor is within this image
    local start_idx = img_start - 1
    local end_idx = img_end - 1

    if col >= start_idx and col <= end_idx then
      -- Extract alt, url, and title from the matched image
      local img_str = line:sub(img_start, img_end)
      local alt, url, title = img_str:match('^%!%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)$')

      if alt and url and title then
        return {
          type = "image_with_title",
          alt = alt,
          url = url,
          title = title,
          start_pos = img_start,
          end_pos = img_end,
          line_num = cursor[1],
        }
      end
    end

    init = img_end + 1
  end

  -- Try to match basic image links ![alt](url)
  init = 1
  while true do
    local img_start, img_end = line:find(M.patterns.image_link, init)
    if not img_start then
      break
    end

    -- Check if cursor is within this image
    local start_idx = img_start - 1
    local end_idx = img_end - 1

    if col >= start_idx and col <= end_idx then
      -- Extract alt and url from the matched image
      local img_str = line:sub(img_start, img_end)
      local alt, url = img_str:match("^%!%[([^%]]*)%]%(([^%)]+)%)$")

      if alt and url then
        -- Check if this is actually an image with title that we missed
        -- (e.g., title with single quotes or no quotes)
        local url_trimmed = url:match("^%s*(.-)%s*$")
        local url_part, title_part = url_trimmed:match('^([^%s]+)%s+"([^"]+)"$')
        if url_part and title_part then
          return {
            type = "image_with_title",
            alt = alt,
            url = url_part,
            title = title_part,
            start_pos = img_start,
            end_pos = img_end,
            line_num = cursor[1],
          }
        end

        return {
          type = "image",
          alt = alt,
          url = url_trimmed,
          start_pos = img_start,
          end_pos = img_end,
          line_num = cursor[1],
        }
      end
    end

    init = img_end + 1
  end

  return nil
end

---Insert a new image link
---@return nil
function M.insert_image()
  -- Prompt for alt text (allow empty by providing "" default)
  local alt = utils.input("Alt text: ", "")
  if alt == nil then
    return
  end

  -- Prompt for URL (required, no default)
  local url = utils.input("URL: ")
  if url == nil then
    return
  end

  -- Prompt for optional title (allow empty by providing "" default)
  local title = utils.input("Title (optional): ", "")

  -- Build image link
  local image
  if title and title ~= "" then
    image = string.format('![%s](%s "%s")', alt, url, title)
  else
    image = string.format("![%s](%s)", alt, url)
  end

  -- Insert image at cursor position
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2]

  local new_line = line:sub(1, col) .. image .. line:sub(col + 1)
  utils.set_line(cursor[1], new_line)

  -- Move cursor after the image
  utils.set_cursor(cursor[1], col + #image)

  utils.notify("Image inserted")
end

---Convert selection to image link
---@return nil
function M.selection_to_image()
  -- Exit visual mode first to update marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Only support single line for now
  if start_row ~= end_row then
    utils.notify("Multi-line images not supported", vim.log.levels.WARN)
    return
  end

  local line = utils.get_line(start_row)

  -- Extract selected text (vim columns are 1-indexed)
  local alt = line:sub(start_col, end_col)

  -- Trim any whitespace
  alt = alt:match("^%s*(.-)%s*$")

  if alt == "" then
    utils.notify("No text selected", vim.log.levels.WARN)
    return
  end

  -- Prompt for URL (required)
  local url = utils.input("URL: ")
  if url == nil then
    return
  end

  -- Prompt for optional title (allow empty by providing "" default)
  local title = utils.input("Title (optional): ", "")

  -- Build image link
  local image
  if title and title ~= "" then
    image = string.format('![%s](%s "%s")', alt, url, title)
  else
    image = string.format("![%s](%s)", alt, url)
  end

  -- Replace selection with image
  local new_line = line:sub(1, start_col - 1) .. image .. line:sub(end_col + 1)
  utils.set_line(start_row, new_line)

  -- Move cursor to after the image
  utils.set_cursor(start_row, start_col - 1 + #image)

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

  -- Edit alt text (provide default to allow empty)
  local new_alt = utils.input("Alt text: ", image.alt or "")
  if new_alt == nil then
    return
  end

  -- Edit URL (required, no default means empty returns nil)
  local new_url = utils.input("URL: ", image.url)
  if new_url == nil then
    return
  end

  -- Edit title (provide default to allow empty)
  local default_title = image.title or ""
  local new_title = utils.input("Title (optional): ", default_title)

  -- Build updated image
  local new_image
  if new_title and new_title ~= "" then
    new_image = string.format('![%s](%s "%s")', new_alt, new_url, new_title)
  else
    new_image = string.format("![%s](%s)", new_alt, new_url)
  end

  -- Replace image
  local line = utils.get_line(image.line_num)
  local new_line = line:sub(1, image.start_pos - 1) .. new_image .. line:sub(image.end_pos + 1)
  utils.set_line(image.line_num, new_line)

  utils.notify("Image updated")
end

---Toggle between regular link and image link
---@return nil
function M.toggle_image_link()
  local cursor = utils.get_cursor()
  local line = utils.get_current_line()
  local col = cursor[2] -- 0-indexed column

  -- First, check if cursor is on an image link
  local image = M.get_image_at_cursor()
  if image then
    -- Convert image to regular link (remove the !)
    local regular_link
    if image.title then
      regular_link = string.format('[%s](%s "%s")', image.alt, image.url, image.title)
    else
      regular_link = string.format("[%s](%s)", image.alt, image.url)
    end

    local new_line = line:sub(1, image.start_pos - 1) .. regular_link .. line:sub(image.end_pos + 1)
    utils.set_line(cursor[1], new_line)

    utils.notify("Converted to regular link")
    return
  end

  -- Check if cursor is on a regular link
  local init = 1
  while true do
    local link_start, link_end = line:find(M.patterns.regular_link, init)
    if not link_start then
      break
    end

    -- Check if cursor is within this link
    local start_idx = link_start - 1
    local end_idx = link_end - 1

    if col >= start_idx and col <= end_idx then
      -- Extract text and url from the matched link
      local link_str = line:sub(link_start, link_end)

      -- Try to match link with title first
      local text, url, title = link_str:match('^%[([^%]]*)%]%(([^%s%)]+)%s+"([^"]+)"%)$')

      if not text then
        -- Try basic link pattern
        text, url = link_str:match("^%[([^%]]*)%]%(([^%)]+)%)$")
        if text and url then
          -- Trim URL
          url = url:match("^%s*(.-)%s*$")
          -- Check again for title in URL
          local url_part, title_part = url:match('^([^%s]+)%s+"([^"]+)"$')
          if url_part and title_part then
            url = url_part
            title = title_part
          end
        end
      end

      if text and url then
        -- Convert regular link to image (add !)
        local image_link
        if title then
          image_link = string.format('![%s](%s "%s")', text, url, title)
        else
          image_link = string.format("![%s](%s)", text, url)
        end

        local new_line = line:sub(1, link_start - 1) .. image_link .. line:sub(link_end + 1)
        utils.set_line(cursor[1], new_line)

        utils.notify("Converted to image link")
        return
      end
    end

    init = link_end + 1
  end

  utils.notify("No link or image under cursor", vim.log.levels.WARN)
end

return M
