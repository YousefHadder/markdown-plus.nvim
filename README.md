
<img width="1340" height="413" alt="Screenshot 2025-10-25 at 2 47 19 PM" src="https://github.com/user-attachments/assets/8a44f9f7-5ca5-4c3f-8298-6a55e16a3f3c" />

<div align="center">

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github&color=blue)](https://github.com/yousefhadder/markdown-plus.nvim/releases)
[![LuaRocks](https://img.shields.io/luarocks/v/yousefhadder/markdown-plus.nvim?style=flat-square&logo=lua&color=purple)](https://luarocks.org/modules/yousefhadder/markdown-plus.nvim)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

[![Tests](https://img.shields.io/github/actions/workflow/status/yousefhadder/markdown-plus.nvim/tests.yml?branch=main&style=flat-square&logo=github&label=Tests)](https://github.com/yousefhadder/markdown-plus.nvim/actions/workflows/tests.yml)
[![Neovim](https://img.shields.io/badge/Neovim%200.11+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua%205.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org/)

[![GitHub stars](https://img.shields.io/github/stars/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github)](https://github.com/yousefhadder/markdown-plus.nvim/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github)](https://github.com/yousefhadder/markdown-plus.nvim/issues)
[![GitHub contributors](https://img.shields.io/github/contributors/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github)](https://github.com/yousefhadder/markdown-plus.nvim/graphs/contributors)
[![Dotfyle](https://dotfyle.com/plugins/yousefhadder/markdown-plus.nvim/shield?style=flat-square)](https://dotfyle.com/plugins/yousefhadder/markdown-plus.nvim)

</div>

A comprehensive Neovim plugin that provides modern markdown editing capabilities, implementing features found in popular editors like Typora, Mark Text, and Obsidian.

**Key Features:** Zero dependencies • Works with any filetype • Full test coverage (85%+) • Extensively documented

## Table of Contents

- [Why markdown-plus.nvim?](#why-markdown-plusnvim)
- [Quick Start](#quick-start)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Keymaps Reference](#keymaps-reference)
- [Configuration](#configuration)
- [Customizing Keymaps](#customizing-keymaps)
- [Contributing & Development](#contributing--development)
- [License](#license)

## Why markdown-plus.nvim?

markdown-plus.nvim brings the best markdown editing experience to Neovim with several key advantages:

- **Zero Dependencies**: No external dependencies required - just install and go
- **Universal Compatibility**: Works with any filetype, not just markdown (great for plain text, notes, org files, etc.)
- **Battle-Tested**: 85%+ test coverage ensures reliability and stability
- **Modern Features**: Implements features from popular editors like Typora, Mark Text, and Obsidian
- **Extensively Documented**: Comprehensive documentation with examples for every feature
- **Actively Maintained**: Regular updates, quick bug fixes, and responsive to community feedback
- **Flexible Configuration**: Modular feature system - enable only what you need
- **Smart Defaults**: Works out of the box with sensible keymaps that respect your existing configuration

## Quick Start

**Using lazy.nvim:**

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
}
```

That's it! The plugin will automatically activate with default keymaps when you open a markdown file.

**Want to customize?**

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
  config = function()
    require("markdown-plus").setup({
      -- Your custom configuration here
    })
  end,
}
```

See [Configuration](#configuration) for all available options.

## Features

<details>
<summary><b>List Management</b></summary>

  <img src="https://vhs.charm.sh/vhs-4rvquCvWyeMiRnG4hrhLRN.gif" alt="Made with VHS">
  <a href="https://vhs.charm.sh">
    <img src="https://stuff.charm.sh/vhs/badge.svg">
  </a>

- **Auto-create next list item**: Press Enter to automatically continue lists
- **Normal mode list creation**: Use `o`/`O` in normal mode to create new list items
- **Smart list indentation**: Use Tab/Shift+Tab to indent/outdent list items
- **Auto-renumber ordered lists**: Automatically renumber when items are added/deleted
- **Smart backspace**: Remove list markers when backspacing on empty items
- **List breaking**: Press Enter twice on empty list items to break out of lists
- **Checkbox support**: Works with all list types (e.g., `- [ ]`, `1. [ ]`, `a. [x]`)
- **Checkbox toggling**: Toggle checkboxes on/off with `<leader>mx` in normal/visual mode or `<C-t>` in insert mode
- **Multiple list types**: Supports unordered (`-`, `*`, `+`), ordered (`1.`, `2.`), letter-based (`a.`, `A.`), and parenthesized variants (`1)`, `a)`, `A)`)
- **Nested lists**: Full support for nested lists with proper renumbering

</details>

<details>
<summary><b>Text Formatting</b></summary>

  <img src="https://vhs.charm.sh/vhs-7mDU5gzKSL21LMD4RztWtj.gif" alt="Made with VHS">
  <a href="https://vhs.charm.sh">
    <img src="https://stuff.charm.sh/vhs/badge.svg">
  </a>

- **Toggle bold**: `<leader>mb` to toggle `**bold**` formatting on selection or word
- **Toggle italic**: `<leader>mi` to toggle `*italic*` formatting on selection or word
- **Toggle strikethrough**: `<leader>ms` to toggle `~~strikethrough~~` formatting on selection or word
- **Toggle inline code**: `<leader>mc` to toggle `` `code` `` formatting on selection or word
- **Convert to code block**: `<leader>mw` to convert the selected text into a code block
- **Clear all formatting**: `<leader>mC` to remove all markdown formatting from selection or word
- **Smart word detection**: Works with words containing hyphens (`test-word`), dots (`file.name`), and underscores (`snake_case`)
- **Visual and normal mode**: All formatting commands work in both visual selection and normal mode (on current word)

</details>

<details>
<summary><b>Headers & Table of Contents</b></summary>

  <img src="https://vhs.charm.sh/vhs-2kFXE5F1L689BRBaCU6PHV.gif" alt="Made with VHS">
  <a href="https://vhs.charm.sh">
    <img src="https://stuff.charm.sh/vhs/badge.svg">
  </a>

- **Header navigation**: Jump between headers with `]]` (next) and `[[` (previous)
- **Promote/demote headers**: Increase/decrease header importance with `<leader>h+` and `<leader>h-`
- **Set header level**: Quickly set header level 1-6 with `<leader>h1` through `<leader>h6`
- **Generate TOC**: Auto-generate table of contents with `<leader>ht` (uses HTML markers to prevent duplicates)
- **Update TOC**: Refresh existing TOC with `<leader>hu` after modifying headers
- **Follow TOC links**: Press `gd` on a TOC link to jump to that header
- **Smart TOC placement**: TOC appears right before first section (after introduction text)
- **Code block aware**: Headers inside code blocks are correctly ignored
- **GitHub-compatible slugs**: Anchor links work correctly on GitHub (handles `Q&A`, `C++`, etc.)

</details>

<details>
<summary><b>Links & References</b></summary>

  <img src="https://vhs.charm.sh/vhs-7uCmx1XuPrxxP0jKpq8LFU.gif" alt="Made with VHS">
  <a href="https://vhs.charm.sh">
    <img src="https://stuff.charm.sh/vhs/badge.svg">
  </a>

- **Insert link**: `<leader>ml` to insert a new markdown link with text and URL
- **Convert selection to link**: Select text and `<leader>ml` to convert it to a link
- **Edit link**: `<leader>me` on a link to edit its text and URL
- **Open links**: Use `gx` (native Neovim) to open links in your browser
- **Auto-convert URL**: `<leader>ma` on a URL to convert it to a markdown link
- **Reference-style links**: Convert between inline `[text](url)` and reference `[text][ref]` styles
- **Convert to reference**: `<leader>mR` to convert inline link to reference-style
- **Convert to inline**: `<leader>mI` to convert reference link to inline
- **Smart URL detection**: Works with bare URLs and properly formatted links

</details>

<details>
<summary><b>Quotes Management</b></summary>

  <img src="https://vhs.charm.sh/vhs-6scYF4Dxo7gAtsxEWXxOQU.gif" alt="Made with VHS">
  <a href="https://vhs.charm.sh">
    <img src="https://stuff.charm.sh/vhs/badge.svg">
  </a>

- **Toggle blockquote**: Use `<leader>mq` to toggle `>` blockquote formatting on the current line or visual selection.
- **Visual and normal mode**: Works in both visual selection and normal mode.

</details>

<details>
<summary><b>Table Support (Phase 1)</b></summary>

- **Create tables**: `<leader>tc` to interactively create a new table with custom dimensions
- **Format tables**: `<leader>tf` to auto-format and align columns
- **Normalize tables**: `<leader>tn` to fix malformed tables
- **Smart navigation**: `<C-l>`/`<C-h>` for cell navigation, `<M-j>`/`<M-k>` for row navigation (insert mode, table-aware)
- **Row operations**: Insert (`<leader>tir`/`<leader>tiR`), delete (`<leader>tdr`), duplicate (`<leader>tyr`)
- **Column operations**: Insert (`<leader>tic`/`<leader>tiC`), delete (`<leader>tdc`), duplicate (`<leader>tyc`)
- **Alignment support**: Left (`:---`), center (`:---:`), right (`---:`)
- **Smart cursor positioning**: Cursor automatically positioned after all operations
- **Table-aware keybindings**: Insert mode navigation only activates in tables

</details>

## Requirements

- Neovim 0.11+ (uses modern Lua APIs)
- No external dependencies

## Installation

<details open>
<summary><b>Using lazy.nvim (Recommended)</b></summary>

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",  -- Load on markdown files by default
  config = function()
    require("markdown-plus").setup({
      -- Configuration options (all optional)
      enabled = true,
      features = {
        list_management = true,  -- Enable list management features
        text_formatting = true,  -- Enable text formatting features
        headers_toc = true,      -- Enable headers and TOC features
        links = true,            -- Enable link management features
      },
      keymaps = {
        enabled = true,  -- Enable default keymaps
      },
      filetypes = { "markdown" },  -- Filetypes to enable the plugin for
    })
  end,
}
```

**Using with multiple filetypes:**

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = { "markdown", "text", "txt" },  -- Load on multiple filetypes
  config = function()
    require("markdown-plus").setup({
      filetypes = { "markdown", "text", "txt" },  -- Enable for these filetypes
    })
  end,
}
```

</details>

<details>
<summary>Using LuaRocks</summary>

```bash
# Install via LuaRocks
luarocks install markdown-plus.nvim

# Or install development version
luarocks install --server=https://luarocks.org/dev markdown-plus.nvim
```

Then add to your Neovim configuration:

```lua
-- No plugin manager needed, already installed via LuaRocks
require("markdown-plus").setup({
  -- Your configuration here
})
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

### Toggle Checkboxes

```markdown
Position cursor on a list item and press <leader>mx:

- Regular item       ← Press <leader>mx
- [ ] Regular item   ← Press <leader>mx again
- [x] Regular item   ← Press <leader>mx again (cycles back to unchecked)

Works with all list types:
1. Item              → 1. [ ] Item → 1. [x] Item
a. Item              → a. [ ] Item → a. [x] Item

Visual mode - select multiple lines and press <leader>mx:
- [ ] Task 1         → - [x] Task 1
- [x] Task 2         → - [ ] Task 2
- Regular            → - [ ] Regular

Insert mode - press Ctrl+T while on a list item:
- [ ] Todo           → - [x] Todo (cursor stays in place)
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

a. Letter-based lists supported
b. Press 'o' for next letter ⬅️
c. Press 'O' for previous letter ⬅️

1) Parenthesized lists work too
2) Auto-increments correctly ⬅️
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

### Convert to Code Block

```markdown
Select any text in visual block mode and convert it to a code block:
1. Enter visual block mode with `V`
2. Select the rows you want to convert
3. Press `<leader>mw`
4. Enter the language for the code block (e.g., `lua`, `python`)

Example:
This is some text
and more text

→

    ```txt
    This is some text
    and more text
    ```
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

<details>
<summary>Headers & TOC Examples</summary>

### Header Navigation

```markdown
Use ]] and [[ to jump between headers quickly:
# Main Title       ← Press ]] to jump here
Content
## Section 1       ← Press ]] to jump here
Content
### Subsection    ← Press ]] to jump here
Content
Press [[ to jump backwards
```

### Promote/Demote Headers

```markdown
Position cursor on any header and adjust its level:
### Subsection    ← Press <leader>h+ → ## Subsection (promoted)
## Section        ← Press <leader>h- → ### Section (demoted)
```

### Convert to Header

```markdown
Position cursor on any line:
Regular text      ← Press <leader>h2 → ## Regular text
Already header    ← Press <leader>h4 → #### Already header
```

### Generate Table of Contents

```markdown
# My Document

Press <leader>ht to generate TOC:

<!-- TOC -->

## Table of Contents

- [Section 1](#section-1)
  - [Subsection 1.1](#subsection-1-1)
- [Section 2](#section-2)

<!-- /TOC -->

## Section 1
...
```

**Note:** The TOC is wrapped in HTML comment markers `<!-- TOC -->` and `<!-- /TOC -->`. This prevents duplicate TOCs from being created if you press `<leader>ht` again. To update an existing TOC, use `<leader>hu` instead.

### Update TOC

```markdown
After adding/removing/renaming headers:
1. Press <leader>hu to update the TOC
2. All links are regenerated automatically
3. The content between <!-- TOC --> and <!-- /TOC --> is replaced
```

### Follow TOC Links

```markdown
## Table of Contents

- [Getting Started](#getting-started)  ← Position cursor here
- [API & SDK](#api--sdk)
- [Q&A](#qa)

Press gd to jump directly to that header!

## Getting Started    ← You jump here instantly!
```

### TOC with Symbols (GitHub-Compatible)

```markdown
# API Documentation

## Q&A              → TOC link: [Q&A](#qa)
## API & SDK        → TOC link: [API & SDK](#api--sdk)
## C++ Examples     → TOC link: [C++ Examples](#c-examples)
## What's New?      → TOC link: [What's New?](#whats-new)

All links work correctly on GitHub! ✓
```

### Code Blocks Ignored

```markdown
# Document

## Real Section

\`\`\`bash
# This is NOT in the TOC
## Neither is this
\`\`\`

Press <leader>ht → Only "Real Section" appears in TOC ✓
```

### TOC Window (Navigable)

Open an interactive Table of Contents window to browse and navigate your document structure:

```vim
:Toc          " Open TOC in vertical split
:Toch         " Open TOC in horizontal split
:Toct         " Open TOC in new tab
<leader>hT    " Default keymap to toggle TOC
```

**Features:**
- **Progressive disclosure**: Shows H1-H2 initially, expand on demand
- **Fold/unfold navigation**: `l` to expand, `h` to collapse
- **Color-coded levels**: Each header level has distinct color
- **Visual markers**: `▶` (collapsed), `▼` (expanded)
- **Jump to headers**: Press `<Enter>` on any header
- **Help popup**: Press `?` for keyboard shortcuts

**Example:**
```
Initial View (depth 1-2):
[H1] Main Title
▶ [H2] Getting Started
▶ [H2] Features
▶ [H2] Contributing

After pressing 'l' on "Getting Started":
[H1] Main Title
▼ [H2] Getting Started
    ▶ [H3] Installation
    ▶ [H3] Configuration
▶ [H2] Features
▶ [H2] Contributing
```

**Keymaps (inside TOC):**
- `l` - Expand header to show children
- `h` - Collapse header or jump to parent
- `<Enter>` - Jump to header in source buffer
- `q` - Close TOC window
- `?` - Show help popup

</details>

<details>
<summary>Links & References Examples</summary>

### Insert New Link

```markdown
In normal mode, press <leader>ml:
1. You'll be prompted: "Link text: "
2. Enter the text (e.g., "GitHub")
3. You'll be prompted: "URL: "
4. Enter the URL (e.g., "https://github.com")
5. Result: [GitHub](https://github.com)
```

### Convert Selection to Link

```markdown
Select text in visual mode:
Visit my website  ← Select "my website" with visual mode

Press <leader>ml:
1. You'll be prompted: "URL: "
2. Enter URL (e.g., "https://example.com")
3. Result: Visit [my website](https://example.com)
```

### Edit Existing Link

```markdown
Position cursor anywhere on a link and press <leader>me:

[Old Text](https://old-url.com)  ← cursor here

Press <leader>me:
1. Link text: Old Text (edit or press Enter)
2. URL: https://old-url.com (edit or press Enter)

Result: [New Text](https://new-url.com)
```

### Open Link in Browser

```markdown
Use native Neovim functionality:
[Google](https://google.com)  ← Position cursor here
Press gx to open in browser

https://example.com  ← Works on bare URLs too
Press gx to open
```

### Convert URL to Link

```markdown
Position cursor on a URL and press <leader>ma:

Check out https://github.com/yousefhadder/markdown-plus.nvim

Press <leader>ma:
1. Link text (empty for URL): GitHub Plugin
2. Result: Check out [GitHub Plugin](https://github.com/yousefhadder/markdown-plus.nvim)

Or leave text empty to use URL as text:
Result: [https://github.com/yousefhadder/markdown-plus.nvim](https://github.com/yousefhadder/markdown-plus.nvim)
```

### Reference-Style Links

```markdown
Convert inline link to reference-style with <leader>mR:

[Documentation](https://docs.example.com)  ← cursor here

Press <leader>mR:
Result:
[Documentation][documentation]

... (at end of document)
[documentation]: https://docs.example.com

---

Convert reference link to inline with <leader>mI:

[My Link][myref]  ← cursor here

... (elsewhere in document)
[myref]: https://myref.com

Press <leader>mI:
Result: [My Link](https://myref.com)
```

### Reuse Existing References

```markdown
When converting links with the same text and URL to reference-style,
the reference is reused:

Check out [GitHub](https://github.com) for code.
Visit [GitHub](https://github.com) to see projects.

Press <leader>mR on both:
Result:
Check out [GitHub][github] for code.
Visit [GitHub][github] to see projects.

[github]: https://github.com  ← Only one definition

---

Links with different text create separate references even with same URL:

[dotfiles](https://github.com/yousefhadder/dotfiles)
[My Dotfiles](https://github.com/yousefhadder/dotfiles)

Press <leader>mR on both:
Result:
[dotfiles][dotfiles]
[My Dotfiles][my-dotfiles]

[dotfiles]: https://github.com/yousefhadder/dotfiles
[my-dotfiles]: https://github.com/yousefhadder/dotfiles
```

</details>

<details>
<summary>Quotes Management Examples</summary>

### Toggle Blockquote

```markdown
Position cursor on a line and press `<leader>mq`:
This is a normal line → `> This is a normal line`
`> This is a quoted line` → This is a normal line (toggle off)
```

### Visual Mode Selection

```markdown
Select multiple lines in visual mode and press `<leader>mq`:
1. Enter visual mode with `V` (line-wise visual mode)
2. Select the lines you want to quote
3. Press `<leader>mq`

Example:
Normal line 1
Normal line 2

→

> Normal line 1
> Normal line 2
```

</details>

<details>
<summary>Table Support Examples</summary>

### Create a New Table

```markdown
Press <leader>tc to create a new table interactively:
1. You'll be prompted: "Number of rows: "
2. Enter the number of rows (e.g., 3)
3. You'll be prompted: "Number of columns: "
4. Enter the number of columns (e.g., 4)

Result:
| Header 1 | Header 2 | Header 3 | Header 4 |
|----------|----------|----------|----------|
|          |          |          |          |
|          |          |          |          |
|          |          |          |          |
```

### Format and Normalize Tables

```markdown
Format a table with <leader>tf:
| Name | Age | City |
|---|---|---|
| Alice | 25 | NYC |
| Bob | 30 | LA |

→

| Name  | Age | City |
|-------|-----|------|
| Alice | 25  | NYC  |
| Bob   | 30  | LA   |

Normalize malformed tables with <leader>tn:
| Header 1 | Header 2
|---|---
Missing pipes | fixed automatically

→

| Header 1         | Header 2          |
|------------------|-------------------|
| Missing pipes    | fixed automatically |
```

### Navigate Between Cells

```markdown
In insert mode, use smart navigation (only active in tables):
| Cell 1 | Cell 2 | Cell 3 |
|--------|--------|--------|
| A      | B      | C      | ← cursor here
| D      | E      | F      |

<C-l> - Move to next cell (B → C → D)
<C-h> - Move to previous cell (B → A)
<M-j> - Move to cell below (B → E)
<M-k> - Move to cell above (E → B)
```

### Row Operations

```markdown
Insert row below with <leader>tir:
| Name | Age |
|------|-----|
| Alice | 25 | ← cursor here
| Bob  | 30 |

→

| Name  | Age |
|-------|-----|
| Alice | 25  |
|       |     | ← new row inserted
| Bob   | 30  |

Insert row above with <leader>tiR:
| Name  | Age |
|-------|-----|
|       |     | ← new row inserted
| Alice | 25  | ← cursor was here

Delete row with <leader>tdr:
| Name  | Age |
|-------|-----|
| Alice | 25  | ← cursor here (row deleted)
| Bob   | 30  |

→

| Name | Age |
|------|-----|
| Bob  | 30  |

Duplicate row with <leader>tyr:
| Name  | Age |
|-------|-----|
| Alice | 25  | ← cursor here
| Bob   | 30  |

→

| Name  | Age |
|-------|-----|
| Alice | 25  |
| Alice | 25  | ← duplicated row
| Bob   | 30  |
```

### Column Operations

```markdown
Insert column right with <leader>tic:
| Name  | Age |
|-------|-----|
| Alice | 25  |
| Bob   | 30  |
       ↑ cursor here

→

| Name  | Age |     |
|-------|-----|-----|
| Alice | 25  |     | ← new column
| Bob   | 30  |     |

Insert column left with <leader>tiC:
|     | Name  | Age | ← new column inserted left
|-----|-------|-----|
|     | Alice | 25  |
|     | Bob   | 30  |

Delete column with <leader>tdc:
| Name  | Age | City | ← Age column deleted
|-------|-----|------|
| Alice | 25  | NYC  |

→

| Name  | City |
|-------|------|
| Alice | NYC  |

Duplicate column with <leader>tyc:
| Name  | Age | Age | ← Age column duplicated
|-------|-----|-----|
| Alice | 25  | 25  |
| Bob   | 30  | 30  |
```

### Alignment Support

```markdown
Tables support left, center, and right alignment:

Left-aligned (default):     :---
Center-aligned:             :---:
Right-aligned:              ---:

Example:
| Left | Center | Right |
|:-----|:------:|------:|
| A    | B      | C     |
| D    | E      | F     |

Formatting preserves alignment markers.
```

### Edge Cases

```markdown
Tables handle various edge cases:

Empty cells:
| Header 1 | Header 2 |
|----------|----------|
|          | Data     |
| Data     |          |

Special characters:
| Name      | Symbol |
|-----------|--------|
| Greater   | >      |
| Less      | <      |
| Pipe      | \|     |

Unicode:
| English | Japanese | Emoji |
|---------|----------|-------|
| Hello   | こんにちは | 👋    |
| World   | 世界     | 🌍    |

Malformed tables (normalized automatically):
| No closing pipe
| Missing separator
    →
| No closing pipe    |
|--------------------|
| Missing separator  |
```

### Smart Features

```markdown
**Table-Aware Navigation:**
Insert mode navigation (<C-l>, <C-h>, <M-j>, <M-k>) only activates
when cursor is inside a table. Outside tables, default behavior applies.

**Header Protection:**
Cannot delete header row or separator row. Operations protect table integrity.

**Minimum Constraints:**
- Cannot delete the last column
- Cannot delete the only data row
- Maintains at least one header + separator + one data row

**Smart Cursor Positioning:**
After all operations, cursor is automatically positioned in the most
logical cell (usually first cell of new/modified row/column).
```

</details>

## Keymaps Reference

<details open>
<summary><b>Quick Reference - All Keymaps</b></summary>

| Feature | Keymap | Mode | Description |
|---------|--------|------|-------------|
| **List Management** |
| | `<CR>` | Insert | Auto-continue lists or break out |
| | `<Tab>` | Insert | Indent list item |
| | `<S-Tab>` | Insert | Outdent list item |
| | `<BS>` | Insert | Smart backspace |
| | `o` | Normal | Create next list item |
| | `O` | Normal | Create previous list item |
| | `<leader>mr` | Normal | Manual renumber lists |
| | `<leader>mx` | Normal/Visual | Toggle checkbox |
| | `<C-t>` | Insert | Toggle checkbox |
| **Text Formatting** |
| | `<leader>mb` | Normal/Visual | Toggle **bold** |
| | `<leader>mi` | Normal/Visual | Toggle *italic* |
| | `<leader>ms` | Normal/Visual | Toggle ~~strikethrough~~ |
| | `<leader>mc` | Normal/Visual | Toggle `code` |
| | `<leader>mw` | Visual | Convert selection to code block |
| | `<leader>mC` | Normal/Visual | Clear all formatting |
| **Headers & TOC** |
| | `]]` | Normal | Jump to next header |
| | `[[` | Normal | Jump to previous header |
| | `<leader>h+` | Normal | Promote header |
| | `<leader>h-` | Normal | Demote header |
| | `<leader>h1` to `h6` | Normal | Set header level |
| | `<leader>ht` | Normal | Generate TOC |
| | `<leader>hu` | Normal | Update TOC |
| | `gd` | Normal | Follow TOC link |
| **Links** |
| | `<leader>ml` | Normal | Insert new link |
| | `<leader>ml` | Visual | Convert selection to link |
| | `<leader>me` | Normal | Edit link |
| | `<leader>ma` | Normal | Auto-convert URL |
| | `<leader>mR` | Normal | Convert to reference |
| | `<leader>mI` | Normal | Convert to inline |
| | `gx` | Normal | Open link in browser |
| **Quotes** |
| | `<leader>mq` | Normal/Visual | Toggle blockquote |
| **Tables** |
| | `<leader>tc` | Normal | Create table |
| | `<leader>tf` | Normal | Format table |
| | `<leader>tn` | Normal | Normalize table |
| | `<C-l>` | Insert | Next cell (in tables) |
| | `<C-h>` | Insert | Previous cell (in tables) |
| | `<M-j>` | Insert | Next row (in tables) |
| | `<M-k>` | Insert | Previous row (in tables) |
| | `<leader>tir` | Normal | Insert row below |
| | `<leader>tiR` | Normal | Insert row above |
| | `<leader>tdr` | Normal | Delete row |
| | `<leader>tyr` | Normal | Duplicate row |
| | `<leader>tic` | Normal | Insert column right |
| | `<leader>tiC` | Normal | Insert column left |
| | `<leader>tdc` | Normal | Delete column |
| | `<leader>tyc` | Normal | Duplicate column |

</details>

<details>
<summary><b>Detailed Keymaps by Category</b></summary>

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
| `<leader>mx` | Normal | Toggle checkbox on current line |
| `<leader>md` | Normal | Debug list groups (development) |

### List Management (Visual Mode)

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>mx` | Visual | Toggle checkboxes in selection |

### Text Formatting (Normal & Visual Mode)

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>mb` | Normal/Visual | Toggle **bold** formatting |
| `<leader>mi` | Normal/Visual | Toggle *italic* formatting |
| `<leader>ms` | Normal/Visual | Toggle ~~strikethrough~~ formatting |
| `<leader>mc` | Normal/Visual | Toggle `` `code` `` formatting |
| `<leader>mw` | Visual | Convert selection to code block |
| `<leader>mC` | Normal/Visual | Clear all formatting |

### Headers & TOC (Normal Mode)

| Keymap | Mode | Description |
|--------|------|-------------|
| `]]` | Normal | Jump to next header |
| `[[` | Normal | Jump to previous header |
| `<leader>h+` | Normal | Promote header (increase importance) |
| `<leader>h-` | Normal | Demote header (decrease importance) |
| `<leader>h1` | Normal | Set/convert to H1 |
| `<leader>h2` | Normal | Set/convert to H2 |
| `<leader>h3` | Normal | Set/convert to H3 |
| `<leader>h4` | Normal | Set/convert to H4 |
| `<leader>h5` | Normal | Set/convert to H5 |
| `<leader>h6` | Normal | Set/convert to H6 |
| `<leader>ht` | Normal | Generate table of contents |
| `<leader>hu` | Normal | Update existing table of contents |
| `<leader>hT` | Normal | Toggle navigable TOC window |
| `gd` | Normal | Follow TOC link (jump to header) |

### Links & References (Normal & Visual Mode)

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>ml` | Normal | Insert new markdown link |
| `<leader>ml` | Visual | Convert selection to link |
| `<leader>me` | Normal | Edit link under cursor |
| `<leader>ma` | Normal | Convert URL to markdown link |
| `<leader>mR` | Normal | Convert to reference-style link |
| `<leader>mI` | Normal | Convert to inline link |
| `gx` | Normal | Open link in browser (native Neovim) |

### Quotes Management (Normal & Visual Mode)

 | Keymap       | Mode       | Description                          |
 |--------------|------------|--------------------------------------|
 | `<leader>mq` | Normal     | Toggle blockquote on current line    |
 | `<leader>mq` | Visual     | Toggle blockquote on selected lines  |

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
    headers_toc = true,        -- Headers and TOC features
    links = true,              -- Link management and references
    table = true,              -- Table support features
  },

  -- Keymap configuration
  keymaps = {
    enabled = true,  -- Set to false to disable all default keymaps
  },

  -- Filetypes configuration
  -- Specifies which filetypes will enable the plugin features
  -- Default: { "markdown" }
  filetypes = { "markdown" },
})
```

### Using with Multiple Filetypes

The plugin can be enabled for any filetype, not just markdown. This is useful for:

- Plain text files (`.txt`, `.text`)
- Note-taking formats (`.note`, `.org`)
- Documentation files
- Any text-based format where you want markdown-style formatting

**Example: Enable for markdown and plain text files**

```lua
require("markdown-plus").setup({
  filetypes = { "markdown", "text", "txt" },
})
```

**Example: Enable for custom note-taking setup**

```lua
require("markdown-plus").setup({
  filetypes = { "markdown", "note", "org", "wiki" },
})
```

**Important:** Make sure your plugin manager also loads the plugin for these filetypes:

```lua
-- For lazy.nvim
{
  "yousefhadder/markdown-plus.nvim",
  ft = { "markdown", "text", "txt" },  -- Match your filetypes config
  config = function()
    require("markdown-plus").setup({
      filetypes = { "markdown", "text", "txt" },
    })
  end,
}
```

</details>

### Alternative Configuration Methods

<details>
<summary>Using vim.g (for Vimscript compatibility)</summary>

If you prefer not to call `setup()` or need Vimscript compatibility, you can configure the plugin using `vim.g.markdown_plus`:

#### Using a Table (Lua)

```lua
-- Set before the plugin loads (e.g., in init.lua)
vim.g.markdown_plus = {
  enabled = true,
  features = {
    list_management = true,
    text_formatting = true,
  },
  keymaps = {
    enabled = false,  -- Disable default keymaps
  },
  filetypes = { "markdown", "text" },
}

-- No need to call setup() if you only use vim.g
-- The plugin will automatically use vim.g configuration
```

#### Using a Table (Vimscript)

```vim
" Set before the plugin loads (e.g., in init.vim)
let g:markdown_plus = #{
  \ enabled: v:true,
  \ features: #{
  \   list_management: v:true,
  \   text_formatting: v:false
  \ },
  \ keymaps: #{
  \   enabled: v:true
  \ },
  \ filetypes: ['markdown', 'text']
  \ }
```

#### Using a Function (Dynamic Configuration)

For dynamic configuration based on runtime conditions:

```lua
vim.g.markdown_plus = function()
  return {
    enabled = vim.fn.has("nvim-0.10") == 1,  -- Only enable on Neovim 0.10+
    features = {
      list_management = true,
      text_formatting = not vim.g.vscode,  -- Disable in VSCode
    },
  }
end
```

#### Configuration Priority

When both `vim.g.markdown_plus` and `setup()` are used, they are merged with the following priority:

1. **Lowest**: Default configuration
2. **Middle**: `vim.g.markdown_plus` configuration
3. **Highest**: `setup(opts)` parameter

Example:

```lua
-- This vim.g config sets list_management = false
vim.g.markdown_plus = {
  features = {
    list_management = false,
  },
}

-- But setup() overrides it to true
require("markdown-plus").setup({
  features = {
    list_management = true,  -- Takes precedence over vim.g
  },
})

-- Result: list_management will be true
```

This allows you to:

- Set global defaults with `vim.g`
- Override specific settings with `setup()` for certain filetypes or conditions
- Mix both methods for maximum flexibility

</details>

## Customizing Keymaps

<details>
<summary>Custom Keymap Configuration</summary>

markdown-plus.nvim provides `<Plug>` mappings for all features, allowing you to customize keybindings to your preference.

### Disabling Default Keymaps

To disable all default keymaps and define your own:

```lua
require("markdown-plus").setup({
  keymaps = {
    enabled = false,  -- Disable all default keymaps
  },
})
```

### Using <Plug> Mappings

You can create custom keymaps using the provided `<Plug>` mappings. Add these to your Neovim configuration (after the plugin loads):

#### Text Formatting

```lua
-- Normal mode
vim.keymap.set("n", "<C-b>", "<Plug>(MarkdownPlusBold)")
vim.keymap.set("n", "<C-i>", "<Plug>(MarkdownPlusItalic)")
vim.keymap.set("n", "<C-s>", "<Plug>(MarkdownPlusStrikethrough)")
vim.keymap.set("n", "<C-k>", "<Plug>(MarkdownPlusCode)")
vim.keymap.set("n", "<C-x>", "<Plug>(MarkdownPlusClearFormatting)")

-- Visual mode
vim.keymap.set("x", "<C-b>", "<Plug>(MarkdownPlusBold)")
vim.keymap.set("x", "<C-i>", "<Plug>(MarkdownPlusItalic)")
vim.keymap.set("x", "<C-s>", "<Plug>(MarkdownPlusStrikethrough)")
vim.keymap.set("x", "<C-k>", "<Plug>(MarkdownPlusCode)")
vim.keymap.set("x", "<leader>mw", "<Plug>(MarkdownPlusCodeBlock)")
vim.keymap.set("x", "<C-x>", "<Plug>(MarkdownPlusClearFormatting)")
```

#### Headers & TOC

```lua
vim.keymap.set("n", "gn", "<Plug>(MarkdownPlusNextHeader)")
vim.keymap.set("n", "gp", "<Plug>(MarkdownPlusPrevHeader)")
vim.keymap.set("n", "<leader>h=", "<Plug>(MarkdownPlusPromoteHeader)")
vim.keymap.set("n", "<leader>h-", "<Plug>(MarkdownPlusDemoteHeader)")
vim.keymap.set("n", "<leader>ht", "<Plug>(MarkdownPlusGenerateTOC)")
vim.keymap.set("n", "<leader>hu", "<Plug>(MarkdownPlusUpdateTOC)")
vim.keymap.set("n", "<CR>", "<Plug>(MarkdownPlusFollowLink)")  -- Follow TOC link

-- Header levels (H1-H6)
for i = 1, 6 do
  vim.keymap.set("n", "<leader>" .. i, "<Plug>(MarkdownPlusHeader" .. i .. ")")
end
```

#### Links

```lua
vim.keymap.set("n", "<leader>li", "<Plug>(MarkdownPlusInsertLink)")
vim.keymap.set("v", "<leader>li", "<Plug>(MarkdownPlusSelectionToLink)")
vim.keymap.set("n", "<leader>le", "<Plug>(MarkdownPlusEditLink)")
vim.keymap.set("n", "<leader>lr", "<Plug>(MarkdownPlusConvertToReference)")
vim.keymap.set("n", "<leader>ln", "<Plug>(MarkdownPlusConvertToInline)")
vim.keymap.set("n", "<leader>la", "<Plug>(MarkdownPlusAutoLinkURL)")
```

#### List Management

```lua
-- Insert mode
vim.keymap.set("i", "<C-CR>", "<Plug>(MarkdownPlusListEnter)")
vim.keymap.set("i", "<C-]>", "<Plug>(MarkdownPlusListIndent)")
vim.keymap.set("i", "<C-[>", "<Plug>(MarkdownPlusListOutdent)")
vim.keymap.set("i", "<C-h>", "<Plug>(MarkdownPlusListBackspace)")

-- Normal mode
vim.keymap.set("n", "<leader>lr", "<Plug>(MarkdownPlusRenumberLists)")
vim.keymap.set("n", "<leader>ld", "<Plug>(MarkdownPlusDebugLists)")
vim.keymap.set("n", "o", "<Plug>(MarkdownPlusNewListItemBelow)")
vim.keymap.set("n", "O", "<Plug>(MarkdownPlusNewListItemAbove)")
```

#### Quotes

```lua
-- Normal mode
vim.keymap.set("n", "<C-q>", "<Plug>(MarkdownPlusToggleQuote)")
-- Visual mode
vim.keymap.set("x", "<C-q>", "<Plug>(MarkdownPlusToggleQuote)")
```

### Available <Plug> Mappings

#### Text Formatting

- `<Plug>(MarkdownPlusBold)` - Toggle bold (n, x)
- `<Plug>(MarkdownPlusItalic)` - Toggle italic (n, x)
- `<Plug>(MarkdownPlusStrikethrough)` - Toggle strikethrough (n, x)
- `<Plug>(MarkdownPlusCode)` - Toggle inline code (n, x)
- `<Plug>(MarkdownPlusCodeBlock)` - Convert selection to code block (x)
- `<Plug>(MarkdownPlusClearFormatting)` - Clear all formatting (n, x)

#### Headers & TOC

- `<Plug>(MarkdownPlusNextHeader)` - Jump to next header (n)
- `<Plug>(MarkdownPlusPrevHeader)` - Jump to previous header (n)
- `<Plug>(MarkdownPlusPromoteHeader)` - Promote header (n)
- `<Plug>(MarkdownPlusDemoteHeader)` - Demote header (n)
- `<Plug>(MarkdownPlusGenerateTOC)` - Generate TOC (n)
- `<Plug>(MarkdownPlusUpdateTOC)` - Update TOC (n)
- `<Plug>(MarkdownPlusFollowLink)` - Follow TOC link (n)
- `<Plug>(MarkdownPlusHeader1)` through `<Plug>(MarkdownPlusHeader6)` - Set header level (n)

#### Links

- `<Plug>(MarkdownPlusInsertLink)` - Insert new link (n)
- `<Plug>(MarkdownPlusSelectionToLink)` - Convert selection to link (v)
- `<Plug>(MarkdownPlusEditLink)` - Edit link under cursor (n)
- `<Plug>(MarkdownPlusConvertToReference)` - Convert to reference-style (n)
- `<Plug>(MarkdownPlusConvertToInline)` - Convert to inline link (n)
- `<Plug>(MarkdownPlusAutoLinkURL)` - Auto-convert URL to link (n)

#### List Management

- `<Plug>(MarkdownPlusListEnter)` - Auto-continue list (i)
- `<Plug>(MarkdownPlusListIndent)` - Indent list item (i)
- `<Plug>(MarkdownPlusListOutdent)` - Outdent list item (i)
- `<Plug>(MarkdownPlusListBackspace)` - Smart backspace (i)
- `<Plug>(MarkdownPlusRenumberLists)` - Renumber lists (n)
- `<Plug>(MarkdownPlusDebugLists)` - Debug list groups (n)
- `<Plug>(MarkdownPlusNewListItemBelow)` - New item below (n)
- `<Plug>(MarkdownPlusNewListItemAbove)` - New item above (n)

#### Quotes

- `<Plug>(MarkdownPlusToggleQuote)` - Toggle blockquote (n, x)

### Mixing Default and Custom Keymaps

You can keep the default keymaps enabled and override specific ones:

```lua
require("markdown-plus").setup({
  keymaps = {
    enabled = true,  -- Keep defaults
  },
})

-- Override only specific keymaps in your config
vim.keymap.set("n", "<C-b>", "<Plug>(MarkdownPlusBold)", { buffer = false })  -- Global override
```

Note: The plugin uses `hasmapto()` to check if a `<Plug>` mapping is already mapped before setting defaults, so your custom mappings will take precedence.

</details>

## Contributing & Development

Contributions are welcome! We encourage direct collaboration - you can open issues and pull requests directly to this repository.

- 🐛 **Bug Reports**: Please include steps to reproduce and your Neovim version
- 💡 **Feature Requests**: Feel free to suggest improvements or new features
- 🔧 **Pull Requests**: Focus on single features and include appropriate tests and documentation

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed development guidelines.

### Running Tests

This plugin uses [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for testing.

#### Prerequisites

```bash
# Install plenary.nvim (if not already installed)
# Using lazy.nvim (add to your plugins):
{ "nvim-lua/plenary.nvim" }

# Or clone manually:
git clone https://github.com/nvim-lua/plenary.nvim \
  ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim
```

#### Run Tests

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=spec/markdown-plus/config_spec.lua

# Watch for changes and run tests
make test-watch  # requires 'entr' command

# Run linter
make lint  # requires 'luacheck'

# Format code
make format  # requires 'stylua'

# Check formatting without modifying
make format-check
```

#### Code Quality Tools

**Linter**: [luacheck](https://github.com/mpeterv/luacheck)

```bash
# Install via LuaRocks
luarocks install luacheck
```

**Formatter**: [stylua](https://github.com/JohnnyMorganz/StyLua)

```bash
# Install via Homebrew (macOS)
brew install stylua

# Or via Cargo
cargo install stylua
```

### Test Structure

```
spec/
├── markdown-plus/
│   ├── config_spec.lua       # Configuration tests
│   ├── utils_spec.lua        # Utility function tests
│   ├── list_spec.lua         # List management tests
│   ├── headers_spec.lua      # Headers & TOC tests
│   ├── links_spec.lua        # Link management tests
│   └── quote_spec.lua        # Quote management tests
└── minimal_init.lua          # Test environment setup
```

### Development Workflow

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Add tests for new features
3. Ensure all tests pass: `make test`
4. Run linter: `make lint`
5. Format code: `make format`
6. Submit a pull request

## License

MIT License - see [LICENSE](./LICENSE) file for details.
