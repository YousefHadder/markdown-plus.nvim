local M = {}

-- Valid table alignment values
local VALID_ALIGNMENTS = { left = true, center = true, right = true }

---Validate user configuration
---@param opts markdown-plus.Config User configuration
---@return boolean is_valid True if config is valid
---@return string|nil error_message Error message if config is invalid
function M.validate(opts)
  ---Helper to validate with path context
  ---@param path string Path context for error messages
  ---@param tbl table Validation table
  ---@return boolean is_valid
  ---@return string|nil error_message
  local function validate_path(path, tbl)
    local ok, err = pcall(vim.validate, tbl)
    if not ok then
      return false, path .. ": " .. tostring(err)
    end
    return true
  end

  -- Validate top-level config
  local ok, err = validate_path("config", {
    enabled = { opts.enabled, "boolean", true },
    features = { opts.features, "table", true },
    keymaps = { opts.keymaps, "table", true },
    filetypes = { opts.filetypes, "table", true },
    toc = { opts.toc, "table", true },
    table = { opts.table, "table", true },
  })
  if not ok then
    return false, err
  end

  -- Validate filetypes array
  if opts.filetypes then
    if not vim.islist(opts.filetypes) then
      return false, "config.filetypes: must be an array (list)"
    end
    for i, ft in ipairs(opts.filetypes) do
      if type(ft) ~= "string" then
        return false, string.format("config.filetypes[%d]: must be a string, got %s", i, type(ft))
      end
    end
  end

  -- Validate features
  if opts.features then
    ok, err = validate_path("config.features", {
      list_management = { opts.features.list_management, "boolean", true },
      text_formatting = { opts.features.text_formatting, "boolean", true },
      headers_toc = { opts.features.headers_toc, "boolean", true },
      links = { opts.features.links, "boolean", true },
      quotes = { opts.features.quotes, "boolean", true },
      code_block = { opts.features.code_block, "boolean", true },
      table = { opts.features.table, "boolean", true },
    })
    if not ok then
      return false, err
    end
  end

  -- Validate keymaps
  if opts.keymaps then
    ok, err = validate_path("config.keymaps", {
      enabled = { opts.keymaps.enabled, "boolean", true },
    })
    if not ok then
      return false, err
    end
  end

  -- Validate toc config
  if opts.toc then
    ok, err = validate_path("config.toc", {
      initial_depth = { opts.toc.initial_depth, "number", true },
    })
    if not ok then
      return false, err
    end

    -- Validate initial_depth range
    if opts.toc.initial_depth then
      if opts.toc.initial_depth < 1 or opts.toc.initial_depth > 6 then
        return false, "config.toc.initial_depth: must be between 1 and 6"
      end
    end
  end

  -- Validate table config
  if opts.table then
    ok, err = validate_path("config.table", {
      enabled = { opts.table.enabled, "boolean", true },
      auto_format = { opts.table.auto_format, "boolean", true },
      default_alignment = { opts.table.default_alignment, "string", true },
      confirm_destructive = { opts.table.confirm_destructive, "boolean", true },
      keymaps = { opts.table.keymaps, "table", true },
    })
    if not ok then
      return false, err
    end

    -- Validate default_alignment values
    if opts.table.default_alignment then
      if not VALID_ALIGNMENTS[opts.table.default_alignment] then
        return false, "config.table.default_alignment: must be 'left', 'center', or 'right'"
      end
    end

    -- Validate table keymaps
    if opts.table.keymaps then
      ok, err = validate_path("config.table.keymaps", {
        enabled = { opts.table.keymaps.enabled, "boolean", true },
        prefix = { opts.table.keymaps.prefix, "string", true },
        insert_mode_navigation = { opts.table.keymaps.insert_mode_navigation, "boolean", true },
      })
      if not ok then
        return false, err
      end
    end
  end

  -- Check for unknown top-level fields
  local known_fields = { enabled = true, features = true, keymaps = true, filetypes = true, toc = true, table = true }
  for key in pairs(opts) do
    if not known_fields[key] then
      return false,
        string.format(
          "config: unknown field '%s'. Valid fields are: %s",
          key,
          table.concat(vim.tbl_keys(known_fields), ", ")
        )
    end
  end

  -- Check for unknown feature fields
  if opts.features then
    local known_feature_fields = {
      list_management = true,
      text_formatting = true,
      headers_toc = true,
      links = true,
      quotes = true,
      code_block = true,
      table = true,
    }
    for key in pairs(opts.features) do
      if not known_feature_fields[key] then
        return false,
          string.format(
            "config.features: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_feature_fields), ", ")
          )
      end
    end
  end

  -- Check for unknown toc fields
  if opts.toc then
    local known_toc_fields = { initial_depth = true }
    for key in pairs(opts.toc) do
      if not known_toc_fields[key] then
        return false,
          string.format(
            "config.toc: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_toc_fields), ", ")
          )
      end
    end
  end

  -- Check for unknown table fields
  if opts.table then
    local known_table_fields =
      { enabled = true, auto_format = true, default_alignment = true, confirm_destructive = true, keymaps = true }
    for key in pairs(opts.table) do
      if not known_table_fields[key] then
        return false,
          string.format(
            "config.table: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_table_fields), ", ")
          )
      end
    end

    -- Check for unknown table.keymaps fields
    if opts.table.keymaps then
      local known_table_keymap_fields = { enabled = true, prefix = true, insert_mode_navigation = true }
      for key in pairs(opts.table.keymaps) do
        if not known_table_keymap_fields[key] then
          return false,
            string.format(
              "config.table.keymaps: unknown field '%s'. Valid fields are: %s",
              key,
              table.concat(vim.tbl_keys(known_table_keymap_fields), ", ")
            )
        end
      end
    end
  end

  -- Check for unknown keymap fields
  if opts.keymaps then
    local known_keymap_fields = { enabled = true }
    for key in pairs(opts.keymaps) do
      if not known_keymap_fields[key] then
        return false,
          string.format(
            "config.keymaps: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_keymap_fields), ", ")
          )
      end
    end
  end

  return true
end

return M
