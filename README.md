# markdown-plus.nvim

A comprehensive Neovim plugin that provides modern markdown editing capabilities, implementing features found in popular editors like Typora, Mark Text, and Obsidian.

## Features

### List Management
- **Auto-create next list item**: Press Enter to automatically continue lists
- **Normal mode list creation**: Use `o`/`O` in normal mode to create new list items
- **Smart list indentation**: Use Tab/Shift+Tab to indent/outdent list items
- **Auto-renumber ordered lists**: Automatically renumber when items are added/deleted
- **Smart backspace**: Remove list markers when backspacing on empty items
- **List breaking**: Press Enter twice on empty list items to break out of lists
- **Checkbox support**: Works with both `- [ ]` and `1. [ ]` checkbox lists
- **Mixed list types**: Supports unordered (`-`, `*`, `+`) and ordered (`1.`) lists
- **Nested lists**: Full support for nested lists with proper renumbering

### Text Formatting
- **Toggle bold**: `<leader>mb` to toggle `**bold**` formatting on selection or word
- **Toggle italic**: `<leader>mi` to toggle `*italic*` formatting on selection or word
- **Toggle strikethrough**: `<leader>ms` to toggle `~~strikethrough~~` formatting on selection or word
- **Toggle inline code**: `<leader>mc` to toggle `` `code` `` formatting on selection or word
- **Clear all formatting**: `<leader>mC` to remove all markdown formatting from selection or word
- **Smart word detection**: Works with words containing hyphens (`test-word`), dots (`file.name`), and underscores (`snake_case`)
- **Visual and normal mode**: All formatting commands work in both visual selection and normal mode (on current word)

## Installation

<details>
<summary>Using lazy.nvim</summary>

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
  config = function()
    require("markdown-plus").setup({
      -- Configuration options (all optional)
      enabled = true,
      features = {
        list_management = true,  -- Enable list management features
        text_formatting = true,  -- Enable text formatting features
      },
      keymaps = {
        enabled = true,  -- Enable default keymaps
      },
    })
  end,
}
```
</details>

<details>
<summary>Using packer.nvim</summary>

```lua
use {
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
  config = function()
    require("markdown-plus").setup()
  end,
}
```
</details>

<details>
<summary>Manual Installation</summary>

1. Clone this repository to your Neovim configuration directory:
```bash
cd ~/.config/nvim
git clone https://github.com/yousefhadder/markdown-plus.nvim
```

1. Add to your `init.lua`:
```lua
require("markdown-plus").setup()
```
</details>

## Usage

The plugin automatically activates when you open a markdown file (`.md` extension). All features work seamlessly with Neovim's built-in functionality.

<details>
<summary>List Management Examples</summary>

### Auto-continue Lists
```markdown
- Type your first item and press Enter
- The next item is automatically created ⬅️ (cursor here)
```

### Checkbox Lists
```markdown
- [ ] Press Enter after this unchecked item
- [ ] Next checkbox item is created ⬅️ (cursor here)

1. [x]
2. [ ]
```

### Smart Indentation
```markdown
- Top level item
  - Press Tab to indent ⬅️ (cursor here)
    - Press Tab again for deeper nesting
  - Press Shift+Tab to outdent ⬅️ (cursor here)
```

### List Breaking
```markdown
- Type your item
-
  ⬆️ Press Enter on empty item, then Enter again to break out:

Regular paragraph text continues here.
```

### Smart Backspace
```markdown
- Type some text, then delete it all
- ⬅️ Press Backspace here to remove the bullet entirely
```

### Normal Mode List Creation
```markdown
- Position cursor on this list item
- Press 'o' to create next item ⬅️ (new item appears below)
- Press 'O' to create previous item ⬅️ (new item appears above)

1. Works with ordered lists too
2. Press 'o' to create item 3 below ⬅️
3. Press 'O' to create item between 2 and 3 ⬅️
```
</details>

<details>
<summary>Text Formatting Examples</summary>

### Toggle Bold
```markdown
Position cursor on word and press <leader>mb:
text → **text**
**text** → text (toggle off)

Or select text in visual mode and press <leader>mb:
Select "this text" → **this text**
```

### Toggle Italic
```markdown
Position cursor on word and press <leader>mi:
text → *text*
*text* → text (toggle off)
```

### Toggle Strikethrough
```markdown
Position cursor on word and press <leader>ms:
text → ~~text~~
~~text~~ → text (toggle off)
```

### Toggle Inline Code
```markdown
Position cursor on word and press <leader>mc:
text → `text`
`text` → text (toggle off)
```

### Clear All Formatting
```markdown
Position cursor on formatted word and press <leader>mC:
**bold** *italic* `code` → bold italic code

Or select complex formatted text and press <leader>mC:
This **bold** and *italic* text → This bold and italic text
```

### Smart Word Detection
```markdown
Works with special characters in words:
test-with-hyphens → **test-with-hyphens** (entire word formatted)
file.name.here → *file.name.here* (entire word formatted)
snake_case_word → `snake_case_word` (entire word formatted)
```

### Visual Mode Selection
```markdown
Select any text in visual mode and format it:
1. Enter visual mode with 'v'
2. Select the text you want to format
3. Press <leader>mb (or mi, ms, mc, mC)
4. The entire selection will be formatted

Example: Select "multiple words here" → **multiple words here**
```

</details>

## Keymaps Reference

<details>
<summary>Default Keymaps</summary>

### List Management (Insert Mode)
| Keymap | Mode | Description |
|--------|------|-------------|
| `<CR>` | Insert | Auto-continue lists or break out of lists |
| `<Tab>` | Insert | Indent list item |
| `<S-Tab>` | Insert | Outdent list item |
| `<BS>` | Insert | Smart backspace (removes empty list markers) |

### List Management (Normal Mode)
| Keymap | Mode | Description |
|--------|------|-------------|
| `o` | Normal | Create next list item |
| `O` | Normal | Create previous list item |
| `<leader>mr` | Normal | Manual renumber ordered lists |
| `<leader>md` | Normal | Debug list groups (development) |

### Text Formatting (Normal & Visual Mode)
| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>mb` | Normal/Visual | Toggle **bold** formatting |
| `<leader>mi` | Normal/Visual | Toggle *italic* formatting |
| `<leader>ms` | Normal/Visual | Toggle ~~strikethrough~~ formatting |
| `<leader>mc` | Normal/Visual | Toggle `` `code` `` formatting |
| `<leader>mC` | Normal/Visual | Clear all formatting |

**Note**: In normal mode, these commands operate on the word under cursor. In visual mode, they operate on the selected text.

</details>

## Configuration

<details>
<summary>Configuration Options</summary>

```lua
require("markdown-plus").setup({
  -- Global enable/disable
  enabled = true,

  -- Feature toggles
  features = {
    list_management = true,    -- List management features
    text_formatting = true,    -- Text formatting features
  },

  -- Keymap configuration
  keymaps = {
    enabled = true,  -- Set to false to disable all default keymaps
  },
})
```
</details>

## Tips & Best Practices

<details>
<summary>Helpful Tips</summary>

### Text Formatting Behavior
- **Toggle functionality**: Pressing the same keymap twice will add then remove formatting
- **Word detection**: In normal mode, the cursor can be anywhere in the word - the entire word will be formatted
- **Multi-word support**: Use visual mode to format phrases or multiple words
- **Special characters**: Words with hyphens, dots, and underscores are treated as single words
- **Clear formatting**: `<leader>mC` removes ALL formatting types in one go (bold, italic, code, strikethrough)

### List Management Tips
- **Auto-continuation**: Press Enter on a list item to automatically create the next one
- **Breaking out**: Press Enter twice on an empty list item to exit the list
- **Smart indentation**: Tab/Shift+Tab works on list items without breaking formatting
- **Auto-renumbering**: Ordered lists automatically renumber when you add/remove items
- **Mixed lists**: You can have nested ordered lists inside unordered lists and vice versa

### Workflow Examples
```markdown
# Quick formatting workflow
1. Type your text normally
2. Use hjkl to position cursor on any word
3. Press <leader>mb to make it bold (or other formatting keys)
4. Continue writing

# Visual mode workflow
1. Write a sentence or paragraph
2. Select text with v, V, or Ctrl+v
3. Press formatting key to apply to entire selection

# List workflow
1. Type - and space to start a list
2. Press Enter to continue adding items
3. Press Tab to nest items
4. Press Enter twice on empty item to finish
```

</details>


## Contributing

Contributions are welcome! Each feature is implemented, tested, and refined individually.

- 🐛 **Bug Reports**: Please include steps to reproduce and your Neovim version
- 💡 **Feature Requests**: Feel free to suggest improvements or new features
- 🔧 **Pull Requests**: Focus on single features and include appropriate documentation

## Requirements

- Neovim 0.11+ (uses modern Lua APIs)
- No external dependencies

## License

MIT License - see [LICENSE](./LICENSE) file for details.

