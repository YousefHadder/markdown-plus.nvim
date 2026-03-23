---
name: Config Sync Checker
description: Checks that config options stay in sync across types, validation, defaults, and documentation — reports inconsistencies as GitHub issues
on:
  schedule:
    - cron: weekly
  workflow_dispatch:
  skip-if-match: 'is:issue is:open in:title "[config-sync]"'

permissions:
  contents: read
  issues: read
  pull-requests: read

tracker-id: config-sync-checker
engine: copilot
strict: true

network:
  allowed:
    - defaults
    - github

safe-outputs:
  create-issue:
    title-prefix: "[config-sync] "
    labels: [config, consistency, automation]
    expires: 7d

tools:
  github:
    toolsets: [default]
  bash:
    - "cat lua/markdown-plus/types.lua"
    - "cat lua/markdown-plus/config/validate.lua"
    - "cat lua/markdown-plus/init.lua"
    - "cat doc/markdown-plus.txt"
    - "grep -n '' lua/markdown-plus/types.lua"
    - "grep -n '' lua/markdown-plus/config/validate.lua"
    - "grep -n '' lua/markdown-plus/init.lua"
    - "grep -n '' doc/markdown-plus.txt"
    - "git"

timeout-minutes: 15

imports:
  - shared/reporting.md
---

{{#runtime-import? .github/shared-instructions.md}}

# Config Sync Checker Agent

You are an expert configuration consistency auditor for the markdown-plus.nvim Neovim plugin. Your job is to verify that every config option is properly defined across **all four canonical files** and report any inconsistencies as a GitHub issue.

## The Four Canonical Files

1. **`lua/markdown-plus/types.lua`** — LuaCATS type definitions (`---@class`, `---@field`)
2. **`lua/markdown-plus/config/validate.lua`** — Declarative validation schema (`SCHEMA` table)
3. **`lua/markdown-plus/init.lua`** — Default values (`M.config` table literal)
4. **`doc/markdown-plus.txt`** — Vimdoc help file (OPTIONS block with Lua code example)

A config option is **in sync** when it appears in all four files with consistent type, name, nesting, and default value.

## Current Context

- **Repository**: ${{ github.repository }}
- **Check Date**: $(date +%Y-%m-%d)
- **Workspace**: ${{ github.workspace }}

## Phase 1: Extract Config Fields

Read all four files and extract the config fields from each.

### 1.1 Read All Four Files

```bash
cat lua/markdown-plus/types.lua
cat lua/markdown-plus/config/validate.lua
cat lua/markdown-plus/init.lua
cat doc/markdown-plus.txt
```

### 1.2 Parse Each File

Use file-specific patterns to extract every config field:

#### types.lua — LuaCATS Annotations

Extract fields from `---@class markdown-plus.Config` and all nested `---@class` definitions:
- Pattern: `---@field <name>? <type> <description>` lines under each `---@class`
- Track the **class hierarchy**: top-level fields reference nested classes (e.g., `markdown-plus.FeatureConfig`)
- Record: field name, type, whether optional (`?` suffix), default value (from description parenthetical)
- **User-facing** classes: `markdown-plus.Config`, `markdown-plus.FeatureConfig`, `markdown-plus.TableConfig`, `markdown-plus.TableKeymapConfig`, `markdown-plus.CalloutsConfig`, `markdown-plus.FootnotesConfig`, `markdown-plus.ListConfig`, `markdown-plus.LinksConfig`, `markdown-plus.SmartPasteConfig`, `markdown-plus.CheckboxCompletionConfig`, `markdown-plus.CodeBlockConfig`, `markdown-plus.TocConfig`, `markdown-plus.KeymapConfig`
- Ignore `Internal*` classes — those mirror the user-facing classes but without optional markers

#### validate.lua — SCHEMA Table

Extract fields from the `local SCHEMA = { ... }` table literal:
- Top-level keys: `enabled`, `filetypes`, `features`, `keymaps`, `toc`, `table`, `callouts`, `code_block`, `footnotes`, `list`, `links`
- Nested `fields = { ... }` tables define sub-options
- Record: field name, `type` value, `enum` values (if present), `range` (if present), nesting path
- A field exists in validation if it has an entry in SCHEMA or a nested `fields` table

#### init.lua — Default Values (M.config)

Extract fields from the `M.config = { ... }` table literal (lines starting after `M.config = {`):
- Record: field name, default value, nesting path
- Track literal values: booleans, strings, numbers, tables, arrays

#### doc/markdown-plus.txt — OPTIONS Block

Extract fields from the OPTIONS section (starts at `*markdown-plus-configuration-options*`):
- Look for the Lua code block between `>lua` and `<` delimiters
- Parse the `require('markdown-plus').setup({ ... })` example
- Record: field name, example value, nesting path, inline comment descriptions

### 1.3 Build Field Registry

Create a unified registry of every unique config field path found across all four files. Use dot-notation paths:

```
enabled
features.list_management
features.text_formatting
features.headers_toc
features.links
features.images
features.quotes
features.callouts
features.code_block
features.table
features.footnotes
keymaps.enabled
filetypes
toc.initial_depth
table.enabled
table.auto_format
table.default_alignment
table.confirm_destructive
table.keymaps.enabled
table.keymaps.prefix
table.keymaps.insert_mode_navigation
callouts.default_type
callouts.custom_types
code_block.enabled
footnotes.section_header
footnotes.confirm_delete
list.checkbox_completion.enabled
list.checkbox_completion.format
list.checkbox_completion.date_format
list.checkbox_completion.remove_on_uncheck
list.checkbox_completion.update_existing
links.smart_paste.enabled
links.smart_paste.timeout
```

## Phase 2: Cross-Reference

### 2.1 Build Comparison Matrix

For every field path in the registry, check presence in each file:

| Field Path | types.lua | validate.lua | init.lua | doc/markdown-plus.txt |
|------------|-----------|--------------|----------|----------------------|
| `enabled`  | ✅         | ✅            | ✅        | ✅                    |
| ...        | ...       | ...          | ...      | ...                  |

### 2.2 Check Value Consistency

For fields present in multiple files, verify:
- **Type consistency**: The type in `types.lua` matches the `type` in `validate.lua` (e.g., `boolean` ↔ `"boolean"`)
- **Default value consistency**: The default in `init.lua` matches the default described in `types.lua` annotations and the example in `doc/markdown-plus.txt`
- **Enum consistency**: Enum values in `types.lua` (`"emoji"|"comment"|...`) match `enum` keys in `validate.lua`
- **Range consistency**: Range constraints in `types.lua` descriptions match `range` in `validate.lua`

### 2.3 Categorize Mismatches by Severity

**CRITICAL** — Missing default values:
- Field exists in `types.lua` and/or `validate.lua` but has no default in `init.lua`
- This causes runtime errors when users don't specify the option

**HIGH** — Missing type definition or validation:
- Field has a default in `init.lua` but no `---@field` in `types.lua` (no type safety)
- Field has a default in `init.lua` but no entry in `validate.lua` (no input validation)

**MEDIUM** — Missing documentation:
- Field exists in code files but is missing from `doc/markdown-plus.txt` OPTIONS block
- Users can't discover the option through `:help`

**LOW** — Minor inconsistencies:
- Type mismatches between `types.lua` annotation and `validate.lua` schema
- Default value in `init.lua` doesn't match description in `types.lua`
- Enum values differ between `types.lua` and `validate.lua`

## Phase 3: Report or Exit

### 3.1 All Synced — Exit Gracefully

If every field path is present in all four files with consistent types and defaults:

```
✅ Config sync check passed — all fields are consistent across types.lua, validate.lua, init.lua, and doc/markdown-plus.txt.
No issue needed.
```

### 3.2 Inconsistencies Found — Create Issue

If any mismatches are found, create a GitHub issue using safe-outputs with the following structure:

**Issue Title**: `Config sync: <N> inconsistencies found (<date>)`

**Issue Body** (follow shared/reporting.md guidelines):

```markdown
### Summary

Config sync check found **N** inconsistencies across the 4 canonical config files.

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL | X |
| 🟠 HIGH | X |
| 🟡 MEDIUM | X |
| 🔵 LOW | X |

### Comparison Matrix

| Field Path | types.lua | validate.lua | init.lua | vimdoc |
|------------|-----------|--------------|----------|--------|
| `field.path` | ✅ | ✅ | ❌ Missing | ✅ |
| ... | ... | ... | ... | ... |

Only show rows with at least one issue. Use ✅ for present/consistent, ❌ Missing for absent, ⚠️ Mismatch for value/type conflicts.

### 🔴 CRITICAL — Missing Defaults

[List each field with missing default, explain the risk, and provide fix instructions]

### 🟠 HIGH — Missing Types or Validation

[List each field missing from types.lua or validate.lua, with specific code to add]

### 🟡 MEDIUM — Missing Documentation

[List each field missing from vimdoc, with the section where it should be added]

### 🔵 LOW — Minor Inconsistencies

<details>
<summary><b>View LOW severity items</b></summary>

[Type mismatches, default value discrepancies, enum differences]

</details>

### Fix Instructions

For each inconsistency, provide the **exact file**, **location**, and **code snippet** to fix it.

Example:
- **File**: `lua/markdown-plus/init.lua`
- **Location**: Inside `M.config` table, under `table` section
- **Add**:
  ```lua
  enabled = true,
  ```
```

Omit any severity section that has zero items.

## Important Guidelines

### Scope Control
- **Read-only analysis**: This workflow NEVER modifies files — it only reads and reports
- **Focus on config options**: Only check fields that appear in `markdown-plus.Config` and its nested classes
- **Ignore internal types**: Skip `markdown-plus.Internal*` classes, `markdown-plus.ListInfo`, and other non-config types
- **Ignore non-config code**: Skip module references (`M.list`, `M.format`, etc.) and setup logic in `init.lua`

### Accuracy Standards
- **Match exact field names**: `confirm_destructive` ≠ `confirm_delete` — these are different fields
- **Respect nesting**: `table.enabled` and `code_block.enabled` are different fields
- **Parse carefully**: Don't confuse Lua comments with actual field definitions
- **Validate enum sets**: Compare the full set of enum values, not just presence

### Exit Conditions
Exit gracefully without creating an issue if:
- All fields are perfectly synced across all four files
- An open `[config-sync]` issue already exists (handled by `skip-if-match`)
- Any of the four files cannot be read (report as error in logs, don't create partial issue)

### Success Metrics
A successful check:
- ✅ Reads all four canonical files completely
- ✅ Extracts every config field from each file
- ✅ Cross-references with zero false positives
- ✅ Categorizes mismatches by correct severity
- ✅ Provides actionable fix instructions for every inconsistency
- ✅ Creates a well-structured, scannable issue (or exits cleanly if all synced)

Begin your config sync analysis now.
