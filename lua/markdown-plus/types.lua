---@meta

---User configuration for markdown-plus.nvim
---Can be provided via setup() or vim.g.markdown_plus (table or function)
---@class markdown-plus.Config
---@field enabled? boolean Enable the plugin (default: true)
---@field features? markdown-plus.FeatureConfig Feature toggles
---@field keymaps? markdown-plus.KeymapConfig Keymap configuration
---@field filetypes? string[] Filetypes to enable plugin for (default: {"markdown"})
---@field code_block? markdown-plus.CodeBlockConfig Code block configuration
---@field toc? markdown-plus.TocConfig TOC window configuration
---@field table? markdown-plus.TableConfig Table configuration
---@field callouts? markdown-plus.CalloutsConfig Callouts configuration
---@field footnotes? markdown-plus.FootnotesConfig Footnotes configuration

---Feature configuration
---@class markdown-plus.FeatureConfig
---@field list_management? boolean Enable list management (default: true)
---@field text_formatting? boolean Enable text formatting (default: true)
---@field headers_toc? boolean Enable headers and TOC (default: true)
---@field links? boolean Enable link management (default: true)
---@field images? boolean Enable image link management (default: true)
---@field quotes? boolean Enable quote management (default: true)
---@field callouts? boolean Enable callout management (default: true)
---@field code_block? boolean Enable code block management (default: true)
---@field table? boolean Enable table management (default: true)
---@field footnotes? boolean Enable footnotes management (default: true)

---Table configuration
---@class markdown-plus.TableConfig
---@field enabled? boolean Enable table features (default: true)
---@field auto_format? boolean Automatically format tables on edit (default: true)
---@field default_alignment? string Default column alignment: 'left', 'center', 'right' (default: 'left')
---@field confirm_destructive? boolean Confirm before destructive operations like transpose/sort (default: true)
---@field keymaps? markdown-plus.TableKeymapConfig Table keymap configuration

---Table keymap configuration
---@class markdown-plus.TableKeymapConfig
---@field enabled? boolean Enable default table keymaps (default: true)
---@field prefix? string Keymap prefix (default: '<leader>t')
---@field insert_mode_navigation? boolean Enable insert mode cell navigation with Alt+hjkl (default: true)

---Callouts configuration
---@class markdown-plus.CalloutsConfig
---@field default_type? string Default callout type (default: "NOTE")
---@field custom_types? string[] Custom callout types to add to standard GFM types (default: {})

---Footnotes configuration
---@class markdown-plus.FootnotesConfig
---@field section_header? string Header text for footnotes section (default: "Footnotes")
---@field confirm_delete? boolean Confirm before deleting footnotes (default: true)

---Code block configuration
---@class markdown-plus.CodeBlockConfig
---@field enabled? boolean Enable code block features (default: true)

---TOC window configuration
---@class markdown-plus.TocConfig
---@field initial_depth? number Initial depth to show in TOC window (default: 2, range: 1-6)

---Keymap configuration
---@class markdown-plus.KeymapConfig
---@field enabled? boolean Enable default keymaps (default: true)

---Internal configuration (with all optional fields resolved)
---@class markdown-plus.InternalConfig
---@field enabled boolean
---@field features markdown-plus.InternalFeatureConfig
---@field keymaps markdown-plus.InternalKeymapConfig
---@field filetypes string[]
---@field toc markdown-plus.InternalTocConfig
---@field table markdown-plus.InternalTableConfig
---@field callouts markdown-plus.InternalCalloutsConfig
---@field code_block markdown-plus.InternalCodeBlockConfig
---@field footnotes markdown-plus.InternalFootnotesConfig

---Internal feature configuration
---@class markdown-plus.InternalFeatureConfig
---@field list_management boolean
---@field text_formatting boolean
---@field headers_toc boolean
---@field links boolean
---@field images boolean
---@field quotes boolean
---@field callouts boolean
---@field code_block boolean
---@field table boolean
---@field footnotes boolean

---Internal table configuration
---@class markdown-plus.InternalTableConfig
---@field enabled boolean
---@field auto_format boolean
---@field default_alignment string
---@field confirm_destructive boolean
---@field keymaps markdown-plus.InternalTableKeymapConfig

---Internal table keymap configuration
---@class markdown-plus.InternalTableKeymapConfig
---@field enabled boolean
---@field prefix string
---@field insert_mode_navigation boolean

---Internal code block configuration
---@class markdown-plus.InternalCodeBlockConfig
---@field enabled boolean

---Internal keymap configuration
---@class markdown-plus.InternalKeymapConfig
---@field enabled boolean

---Internal TOC configuration
---@class markdown-plus.InternalTocConfig
---@field initial_depth number

---Internal callouts configuration
---@class markdown-plus.InternalCalloutsConfig
---@field default_type string
---@field custom_types string[]

---Internal footnotes configuration
---@class markdown-plus.InternalFootnotesConfig
---@field section_header string
---@field confirm_delete boolean

---@class markdown-plus.ListInfo
---@field type string List type: "unordered", "ordered", "ordered_paren", "letter_lower", "letter_lower_paren", "letter_upper", "letter_upper_paren"
---@field marker string The list marker without delimiter (e.g., "1", "a", "-")
---@field full_marker string The complete marker with delimiter (e.g., "1.", "a)", "-")
---@field indent string Leading whitespace before the marker
---@field checkbox string|nil Checkbox state if present: "[ ]", "[x]", "[X]", or nil

-- Note: Footnote types are defined in lua/markdown-plus/footnotes/parser.lua:
-- - markdown-plus.footnotes.Reference
-- - markdown-plus.footnotes.Definition
-- - markdown-plus.footnotes.Footnote

return {}
