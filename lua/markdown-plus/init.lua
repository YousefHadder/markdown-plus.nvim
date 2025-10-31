-- Main entry point for markdown-plus.nvim
local M = {}

---@type markdown-plus.InternalConfig
M.config = {
  enabled = true,
  features = {
    list_management = true,
    text_formatting = true,
    links = true,
    headers_toc = true,
    quotes = true,
    code_block = true,
    table = true,
  },
  keymaps = {
    enabled = true,
  },
  filetypes = { "markdown" },
  table = {
    enabled = true,
    auto_format = true,
    default_alignment = "left",
    keymaps = {
      enabled = true,
      prefix = "<leader>t",
    },
  },
}

-- Module references
M.list = nil
M.format = nil
M.links = nil
M.headers = nil
M.quotes = nil
M.table = nil

---Get user configuration from vim.g.markdown_plus
---Supports both table and function forms
---@return markdown-plus.Config
local function get_vim_g_config()
  local vim_g = vim.g.markdown_plus

  if vim_g == nil then
    return {}
  end

  if type(vim_g) == "table" then
    return vim_g
  elseif type(vim_g) == "function" then
    local ok, result = pcall(vim_g)
    if ok and type(result) == "table" then
      return result
    elseif ok then
      vim.notify(
        string.format("markdown-plus.nvim: vim.g.markdown_plus function returned %s instead of a table", type(result)),
        vim.log.levels.WARN
      )
      return {}
    else
      vim.notify(
        string.format("markdown-plus.nvim: vim.g.markdown_plus function failed: %s", tostring(result)),
        vim.log.levels.ERROR
      )
      return {}
    end
  else
    vim.notify(
      string.format("markdown-plus.nvim: vim.g.markdown_plus must be a table or function, got %s", type(vim_g)),
      vim.log.levels.WARN
    )
    return {}
  end
end

---Setup markdown-plus.nvim with user configuration
---Configuration priority: vim.g.markdown_plus < setup(opts)
---@param opts? markdown-plus.Config User configuration
---@return nil
function M.setup(opts)
  opts = opts or {}

  -- Get vim.g config and merge with setup() parameter
  -- setup() parameter takes precedence over vim.g
  local vim_g_config = get_vim_g_config()
  local merged_opts = vim.tbl_deep_extend("force", vim_g_config, opts)

  -- Validate merged configuration
  local validator = require("markdown-plus.config.validate")
  local ok, err = validator.validate(merged_opts)
  if not ok then
    vim.notify(string.format("markdown-plus.nvim: Invalid configuration\n%s", err), vim.log.levels.ERROR)
    return
  end

  -- Merge validated config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, merged_opts)

  -- Only load if enabled
  if not M.config.enabled then
    return
  end

  -- Load modules based on enabled features
  if M.config.features.list_management then
    M.list = require("markdown-plus.list")
    M.list.setup(M.config)
  end

  if M.config.features.text_formatting then
    M.format = require("markdown-plus.format")
    M.format.setup(M.config)
  end

  if M.config.features.headers_toc then
    M.headers = require("markdown-plus.headers")
    M.headers.setup(M.config)
  end

  if M.config.features.links then
    M.links = require("markdown-plus.links")
    M.links.setup(M.config)
  end

  if M.config.features.quotes then
    M.quotes = require("markdown-plus.quote")
    M.quotes.setup(M.config)
  end

  if M.config.features.table then
    M.table = require("markdown-plus.table")
    if M.config.table then
      M.table.setup(M.config.table)
    else
      M.table.setup()
    end
  end

  -- Set up autocommands for markdown files
  M.setup_autocmds()
end

---Set up autocommands for markdown files
---@return nil
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("MarkdownPlus", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = M.config.filetypes or "markdown",
    callback = function()
      -- Enable features for markdown files
      if M.list then
        M.list.enable()
      end
      if M.format then
        M.format.enable()
      end
      if M.headers then
        M.headers.enable()
      end
      if M.links then
        M.links.enable()
      end
      if M.quotes then
        M.quotes.enable()
      end
      if M.table and M.table.setup then
        -- Table module is already set up, keymaps are buffer-local
        require("markdown-plus.table.keymaps").setup(M.config.table or M.table.config)
      end
    end,
  })
end

return M
