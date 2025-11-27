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
    callouts = { opts.callouts, "table", true },
    code_block = { opts.code_block, "table", true },
    footnotes = { opts.footnotes, "table", true },
  })
  if not ok then
    return false, err
  end

  -- Validate filetypes array
  if opts.filetypes then
    if not vim.tbl_islist(opts.filetypes) then
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
      images = { opts.features.images, "boolean", true },
      quotes = { opts.features.quotes, "boolean", true },
      callouts = { opts.features.callouts, "boolean", true },
      code_block = { opts.features.code_block, "boolean", true },
      table = { opts.features.table, "boolean", true },
      footnotes = { opts.features.footnotes, "boolean", true },
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

  -- Validate code_block config
  if opts.code_block then
    ok, err = validate_path("config.code_block", {
      enabled = { opts.code_block.enabled, "boolean", true },
    })
    if not ok then
      return false, err
    end

    -- Check for unknown code_block fields
    local known_code_block_fields = { enabled = true }
    for key in pairs(opts.code_block) do
      if not known_code_block_fields[key] then
        return false,
          string.format(
            "config.code_block: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_code_block_fields), ", ")
          )
      end
    end
  end

  -- Check for unknown top-level fields
  local known_fields = {
    enabled = true,
    features = true,
    keymaps = true,
    filetypes = true,
    toc = true,
    table = true,
    callouts = true,
    code_block = true,
    footnotes = true,
  }
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
      images = true,
      quotes = true,
      callouts = true,
      code_block = true,
      table = true,
      footnotes = true,
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

  -- Validate callouts config
  if opts.callouts then
    ok, err = validate_path("config.callouts", {
      default_type = { opts.callouts.default_type, "string", true },
      custom_types = { opts.callouts.custom_types, "table", true },
    })
    if not ok then
      return false, err
    end

    -- Standard GFM callout types
    local standard_types = { NOTE = true, TIP = true, IMPORTANT = true, WARNING = true, CAUTION = true }

    -- Validate default_type is a valid type
    if opts.callouts.default_type then
      local is_standard = standard_types[opts.callouts.default_type]
      local is_custom = opts.callouts.custom_types
        and vim.tbl_contains(opts.callouts.custom_types, opts.callouts.default_type)

      if not is_standard and not is_custom then
        return false,
          string.format(
            "config.callouts.default_type: '%s' is not a valid callout type. Must be one of: %s%s",
            opts.callouts.default_type,
            table.concat(vim.tbl_keys(standard_types), ", "),
            opts.callouts.custom_types and " or one of your custom_types" or ""
          )
      end
    end

    -- Validate custom_types array
    if opts.callouts.custom_types then
      if not vim.tbl_islist(opts.callouts.custom_types) then
        return false, "config.callouts.custom_types: must be an array (list)"
      end
      for i, custom_type in ipairs(opts.callouts.custom_types) do
        if type(custom_type) ~= "string" then
          return false,
            string.format("config.callouts.custom_types[%d]: must be a string, got %s", i, type(custom_type))
        end
        -- Validate only A-Z letters
        if not custom_type:match("^[A-Z]+$") then
          return false,
            string.format(
              "config.callouts.custom_types[%d]: must contain only uppercase letters A-Z (got '%s')",
              i,
              custom_type
            )
        end
      end
    end

    -- Check for unknown callouts fields
    local known_callouts_fields = { default_type = true, custom_types = true }
    for key in pairs(opts.callouts) do
      if not known_callouts_fields[key] then
        return false,
          string.format(
            "config.callouts: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_callouts_fields), ", ")
          )
      end
    end
  end

  -- Validate footnotes config
  if opts.footnotes then
    ok, err = validate_path("config.footnotes", {
      section_header = { opts.footnotes.section_header, "string", true },
      confirm_delete = { opts.footnotes.confirm_delete, "boolean", true },
    })
    if not ok then
      return false, err
    end

    -- Check for unknown footnotes fields
    local known_footnotes_fields = { section_header = true, confirm_delete = true }
    for key in pairs(opts.footnotes) do
      if not known_footnotes_fields[key] then
        return false,
          string.format(
            "config.footnotes: unknown field '%s'. Valid fields are: %s",
            key,
            table.concat(vim.tbl_keys(known_footnotes_fields), ", ")
          )
      end
    end
  end

  return true
end

return M
