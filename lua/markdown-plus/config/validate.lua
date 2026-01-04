-- Schema-based configuration validation for markdown-plus.nvim
-- Replaces the repetitive imperative validation with a declarative approach

local M = {}

---@class markdown-plus.FieldSchema
---@field type "boolean"|"string"|"number"|"table"|"array" Expected type
---@field optional? boolean Whether field is optional (default: true)
---@field enum? table<string, boolean> Valid enum values
---@field range? {min: number, max: number} Valid range for numbers
---@field array_type? string Type of array elements
---@field array_validator? fun(item: any, index: number): boolean, string? Custom array item validator
---@field validator? fun(value: any, path: string, root_opts: table): boolean, string? Custom validator
---@field fields? table<string, markdown-plus.FieldSchema> Nested fields for tables

-- Schema definition - single source of truth for config structure
local SCHEMA = {
  enabled = { type = "boolean" },
  filetypes = { type = "array", array_type = "string" },

  features = {
    type = "table",
    fields = {
      list_management = { type = "boolean" },
      text_formatting = { type = "boolean" },
      headers_toc = { type = "boolean" },
      links = { type = "boolean" },
      images = { type = "boolean" },
      quotes = { type = "boolean" },
      callouts = { type = "boolean" },
      code_block = { type = "boolean" },
      table = { type = "boolean" },
      footnotes = { type = "boolean" },
    },
  },

  keymaps = {
    type = "table",
    fields = {
      enabled = { type = "boolean" },
    },
  },

  toc = {
    type = "table",
    fields = {
      initial_depth = { type = "number", range = { min = 1, max = 6 } },
    },
  },

  table = {
    type = "table",
    fields = {
      enabled = { type = "boolean" },
      auto_format = { type = "boolean" },
      default_alignment = { type = "string", enum = { left = true, center = true, right = true } },
      confirm_destructive = { type = "boolean" },
      keymaps = {
        type = "table",
        fields = {
          enabled = { type = "boolean" },
          prefix = { type = "string" },
          insert_mode_navigation = { type = "boolean" },
        },
      },
    },
  },

  callouts = {
    type = "table",
    fields = {
      default_type = {
        type = "string",
        -- Custom validator for callout type (depends on custom_types)
        validator = function(value, path, root_opts)
          local standard = { NOTE = true, TIP = true, IMPORTANT = true, WARNING = true, CAUTION = true }
          if standard[value] then
            return true
          end
          if root_opts.callouts and root_opts.callouts.custom_types then
            if vim.tbl_contains(root_opts.callouts.custom_types, value) then
              return true
            end
          end
          local valid_types = vim.tbl_keys(standard)
          table.sort(valid_types)
          local suffix = ""
          if root_opts.callouts and root_opts.callouts.custom_types and #root_opts.callouts.custom_types > 0 then
            suffix = " or one of your custom_types"
          end
          return false,
            string.format(
              "%s: '%s' is not a valid callout type. Must be one of: %s%s",
              path,
              value,
              table.concat(valid_types, ", "),
              suffix
            )
        end,
      },
      custom_types = {
        type = "array",
        array_type = "string",
        array_validator = function(item, _)
          if not item:match("^[A-Z]+$") then
            return false, string.format("must contain only uppercase letters A-Z (got '%s')", item)
          end
          return true
        end,
      },
    },
  },

  code_block = {
    type = "table",
    fields = {
      enabled = { type = "boolean" },
    },
  },

  footnotes = {
    type = "table",
    fields = {
      section_header = { type = "string" },
      confirm_delete = { type = "boolean" },
    },
  },

  list = {
    type = "table",
    fields = {
      checkbox_completion = {
        type = "table",
        fields = {
          enabled = { type = "boolean" },
          format = { type = "string", enum = { emoji = true, comment = true, dataview = true, parenthetical = true } },
          date_format = { type = "string" },
          remove_on_uncheck = { type = "boolean" },
          update_existing = { type = "boolean" },
        },
      },
    },
  },

  links = {
    type = "table",
    fields = {
      smart_paste = {
        type = "table",
        fields = {
          enabled = { type = "boolean" },
          timeout = {
            type = "number",
            validator = function(value, path, _)
              if value <= 0 then
                return false, path .. ": must be a positive number"
              end
              return true
            end,
          },
        },
      },
    },
  },
}

---Get sorted keys for consistent error messages
---@param tbl table
---@return string[]
local function sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl)
  table.sort(keys)
  return keys
end

---Validate a value against a field schema
---@param value any Value to validate
---@param field_schema markdown-plus.FieldSchema Schema for this field
---@param path string Current path for error messages
---@param root_opts table Root options (for cross-field validation)
---@return boolean is_valid
---@return string|nil error_message
local function validate_field(value, field_schema, path, root_opts)
  -- nil is ok for optional fields (all fields optional by default)
  if value == nil then
    if field_schema.optional == false then
      return false, path .. ": required field is missing"
    end
    return true
  end

  -- Type check
  local expected_type = field_schema.type
  if expected_type == "array" then
    -- Must be a table before checking vim.islist()
    if type(value) ~= "table" then
      return false, path .. ": must be an array (list), got " .. type(value)
    end
    if not vim.islist(value) then
      return false, path .. ": must be an array (list)"
    end
    -- Validate array items
    for i, item in ipairs(value) do
      if field_schema.array_type and type(item) ~= field_schema.array_type then
        return false, string.format("%s[%d]: must be a %s, got %s", path, i, field_schema.array_type, type(item))
      end
      if field_schema.array_validator then
        local ok, err = field_schema.array_validator(item, i)
        if not ok then
          return false, string.format("%s[%d]: %s", path, i, err)
        end
      end
    end
  elseif expected_type == "table" then
    if type(value) ~= "table" then
      return false, path .. ": must be a table, got " .. type(value)
    end
  else
    if type(value) ~= expected_type then
      return false, path .. ": must be a " .. expected_type .. ", got " .. type(value)
    end
  end

  -- Enum check
  if field_schema.enum and not field_schema.enum[value] then
    return false, path .. ": must be one of: " .. table.concat(sorted_keys(field_schema.enum), ", ")
  end

  -- Range check
  if field_schema.range then
    if value < field_schema.range.min or value > field_schema.range.max then
      return false, string.format("%s: must be between %d and %d", path, field_schema.range.min, field_schema.range.max)
    end
  end

  -- Custom validator
  if field_schema.validator then
    local ok, err = field_schema.validator(value, path, root_opts)
    if not ok then
      return false, err
    end
  end

  -- Nested fields (for tables)
  if field_schema.fields and type(value) == "table" then
    -- Check for unknown fields
    for key in pairs(value) do
      if not field_schema.fields[key] then
        return false,
          string.format(
            "%s: unknown field '%s'. Valid fields are: %s",
            path,
            key,
            table.concat(sorted_keys(field_schema.fields), ", ")
          )
      end
    end
    -- Validate known fields
    for field_name, nested_schema in pairs(field_schema.fields) do
      local ok, err = validate_field(value[field_name], nested_schema, path .. "." .. field_name, root_opts)
      if not ok then
        return false, err
      end
    end
  end

  return true
end

---Validate user configuration against schema
---@param opts markdown-plus.Config User configuration
---@return boolean is_valid True if config is valid
---@return string|nil error_message Error message if config is invalid
function M.validate(opts)
  -- Check for unknown top-level fields
  for key in pairs(opts) do
    if not SCHEMA[key] then
      return false,
        string.format("config: unknown field '%s'. Valid fields are: %s", key, table.concat(sorted_keys(SCHEMA), ", "))
    end
  end

  -- Validate each field against schema
  for field_name, field_schema in pairs(SCHEMA) do
    local ok, err = validate_field(opts[field_name], field_schema, "config." .. field_name, opts)
    if not ok then
      return false, err
    end
  end

  return true
end

return M
