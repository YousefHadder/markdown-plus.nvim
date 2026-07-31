# Treesitter

markdown-plus uses Treesitter to understand document structure when it is
available, and falls back to regex parsing when it is not. The plugin works
either way — Treesitter just makes it more accurate.

## Requirements

- Neovim 0.11+ (for `vim.treesitter.get_node`)
- The `markdown` and `markdown_inline` parsers

**You almost certainly already have these.** Neovim ships the Markdown parsers
in its own runtime — `:help treesitter` lists Markdown under "Nvim includes
these parsers", and both `markdown` and `markdown_inline` are bundled. On a
stock Neovim 0.11+ install, there is nothing to do.

Check with:

```vim
:checkhealth markdown-plus
```

If the parsers really are missing (an unusual build, or a stripped-down
distribution), install them with a parser manager such as
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter):

```vim
:TSInstall markdown markdown_inline
```

Note that `:TSInstall` is provided by nvim-treesitter, not by Neovim — it won't
exist unless you have that plugin. markdown-plus does not require it.

Both parsers matter. `markdown` handles block structure (lists, code blocks,
tables, blockquotes) and `markdown_inline` handles inline structure (bold,
italic, strikethrough, code spans, links). markdown-plus only asks for the
`markdown` parser directly — `markdown_inline` is pulled in as an injected
language, so if it is missing, inline format detection quietly drops to regex.

> [!NOTE]
> `:checkhealth markdown-plus` only verifies the `markdown` parser, so a missing
> `markdown_inline` will not be reported. See [Verifying It Works](#verifying-it-works)
> for how to confirm the injected parser directly.

## What Treesitter Is Used For

| Area | What it buys you |
|------|-----------------|
| List detection | Reliable parsing of markers, ordered/unordered, task items and nesting |
| Code block detection | markdown-plus knows exactly where fences begin and end, so the list keys defer inside one |
| Format region detection | Bold, italic, strikethrough and inline code are recognized as *regions*, not just strings |

Code block detection is the one you feel most. Every shared list key (`<CR>`,
`<Tab>`, `<S-Tab>`, `<BS>`, `o`, `O`) defers inside a fence, so a
`- item` written inside a ```` ```markdown ```` block is left alone.

> [!IMPORTANT]
> That deferral belongs to the **list handlers**. The formatting toggles have no
> fenced-code guard — `<localleader>mb` inside a fence will still bold the text.
> The code block actions operate inside fences deliberately.

## Fallback Behavior

If Treesitter is missing, the parser is not installed, or a specific element
fails to parse, markdown-plus falls back to regex parsing for that operation.
There is no configuration to set and nothing breaks — you just lose some
precision in ambiguous documents.

Parsers are cached per buffer against `changedtick`, so repeated operations
between edits do not re-parse.

## Smart Formatting

Treesitter is what makes the formatting toggles feel smart rather than literal.

### Toggling Works on the Whole Region

Put the cursor anywhere inside a formatted region and the toggle applies to all
of it — you do not have to select it or sit on a particular word.

```markdown
This is **some bold text** here
              ↑ cursor anywhere in here

Press <localleader>mb →

This is some bold text here
```

Without Treesitter this only reliably works on a single word.

### Nesting Instead of Breaking

Applying a *different* format to already-formatted text nests it rather than
mangling the markers:

```markdown
This is **bold** text
           ↑ cursor here

Press <localleader>mi →

This is ***bold*** text
```

The word is now both bold and italic — markdown-plus wrapped the existing
`**bold**` region rather than breaking its markers.

markdown-plus works out whether you are nesting a new format or toggling the
existing one.

### Visual Selections Inside a Region

If your visual selection is fully contained inside a formatted region, toggling
that format removes it from the whole container rather than splitting it into
fragments:

```markdown
This is **some bold text** here
            └─ selected ─┘

Press <localleader>mb →

This is some bold text here
```

## Highlight and Underline Are Different

`==highlight==` and `++underline++` are **not** part of the standard
`markdown_inline` grammar. They are always detected with regex, even when
Treesitter is installed and working.

In practice this means the region-level smartness above applies to bold, italic,
strikethrough and inline code, but `<localleader>m=` and `<localleader>mu`
behave more literally. This is a grammar limitation, not a bug.

## Verifying It Works

```vim
:checkhealth markdown-plus
```

If something looks wrong:

1. Confirm the parser loads — `:lua =vim.treesitter.get_parser(0, "markdown") ~= nil`
2. Confirm the buffer filetype — `:set filetype?` should report `markdown`
3. Confirm Neovim is 0.11 or newer — `:version`

You can also inspect the tree directly:

```vim
:InspectTree
```

Put the cursor inside some `**bold**` text and check that the node under it is
`strong_emphasis`. If it is not, `markdown_inline` is missing or not injected.

## See Also

- [Troubleshooting](https://github.com/YousefHadder/markdown-plus.nvim/wiki/8.Troubleshooting)
- [Usage Examples](https://github.com/YousefHadder/markdown-plus.nvim/wiki/4.Usage) — the formatting section
- `:help markdown-plus-treesitter`
