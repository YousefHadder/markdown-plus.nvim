---
name: Semantic Function Refactoring
description: Analyzes Lua codebase daily to identify opportunities for semantic function extraction and refactoring
on:
  workflow_dispatch:
  schedule: daily

permissions:
  contents: read
  issues: read
  pull-requests: read

engine: claude

imports:
  - shared/mood.md
  - shared/reporting.md

safe-outputs:
  close-issue:
    required-title-prefix: "[refactor] "
    target: "*"
    max: 10
  create-issue:
    expires: 2d
    title-prefix: "[refactor] "
    labels: [refactoring, code-quality, automated-analysis, cookie]
    max: 1

tools:
  github:
    toolsets: [default, issues]
  edit:
  bash:
    - "find lua -name '*.lua' -type f | sort"
    - "find lua/markdown-plus -name '*.lua' -type f | sort"
    - "find lua/markdown-plus -maxdepth 1 -name '*.lua' -type f | sort"
    - "find lua/markdown-plus -maxdepth 2 -name '*.lua' -type f | sort"
    - "find lua/ -maxdepth 1 -ls"
    - "find lua/markdown-plus/ -maxdepth 1 -ls"
    - "find lua/markdown-plus/ -maxdepth 2 -ls"
    - "wc -l lua/**/*.lua"
    - "head -n * lua/**/*.lua"
    - "grep -rn 'function M\\.' lua --include='*.lua'"
    - "grep -rn 'local function' lua --include='*.lua'"
    - "grep -rn 'function _' lua --include='*.lua'"
    - "grep -rn '^M\\.' lua --include='*.lua'"
    - "cat lua/**/*.lua"

timeout-minutes: 20
strict: true
source: github/gh-aw/.github/workflows/semantic-function-refactor.md@852cb06ad52958b402ed982b69957ffc57ca0619
---

# Semantic Function Clustering and Refactoring

You are an AI agent that analyzes Lua code in a Neovim plugin to identify potential refactoring opportunities by clustering functions semantically and detecting outliers or duplicates.

## Project Context

This is **markdown-plus.nvim** — a Neovim plugin written in Lua 5.1/LuaJIT providing markdown editing features. Key conventions:

- **Module pattern**: `local M = {}` ... `return M` (every file)
- **Naming**: `snake_case` everywhere; private functions prefixed with `_`; booleans use `is_`/`has_` predicates
- **File organization**: small and focused (30–200 lines typical), organized by feature/domain
- **Feature modules** under `lua/markdown-plus/` each follow a consistent sub-module structure:
  - `init.lua` — entry with `setup(config)`, `enable()`, `setup_keymaps()`
  - `parser.lua` — data parsing (regex/treesitter)
  - `manipulation.lua` — state-changing operations
  - `navigation.lua` — movement/traversal
  - `handlers.lua` — event handlers (insert mode, keymaps)
- **Features**: `list/`, `table/`, `headers/`, `links/`, `images/`, `footnotes/`, `quote/`, `callouts/`, `format/`
- **Shared utilities**: `utils.lua`, `keymap_helper.lua`, `treesitter/init.lua`, `types.lua`, `config/validate.lua`
- **Re-exports**: parent `init.lua` re-exports sub-module functions for backwards compatibility
- **Error handling**: validate early, `vim.notify()` with log levels, return `nil`/`false` on failure, `pcall()` for external calls

## Mission

**IMPORTANT: Before performing analysis, close any existing open issues with the title prefix `[refactor]` to avoid duplicate issues.**

Analyze all Lua source files (`.lua` files) under `lua/markdown-plus/` to:
1. **First, close existing open issues** with the `[refactor]` prefix
2. Collect all function names per file (both public `M.` and private `local function` / `_` prefixed)
3. Cluster functions semantically by name and purpose
4. Identify outliers (functions that might be in the wrong file)
5. Detect potential duplicates or near-duplicates across files
6. Suggest refactoring fixes following the project's established patterns

## Important Constraints

1. **Only analyze `.lua` files** under `lua/markdown-plus/` — Ignore all other file types
2. **Skip spec files** — Never analyze files under `spec/`
3. **Focus on feature modules** — Primary analysis area is `lua/markdown-plus/`
4. **Respect the module pattern** — All suggestions must follow `local M = {} ... return M`
5. **One concern per file** — Files should be named after their primary purpose (parser, manipulation, navigation, etc.)
6. **Backwards compatibility** — Re-exports from parent `init.lua` must be preserved

## Close Existing Refactor Issues (CRITICAL FIRST STEP)

**Before performing any analysis**, you must close existing open issues with the `[refactor]` title prefix to prevent duplicate issues.

Use the GitHub API tools to:
1. Search for open issues with title containing `[refactor]` in repository ${{ github.repository }}
2. Close each found issue with a comment explaining a new analysis is being performed
3. Use the `close_issue` safe output to close these issues

**Important**: The `close-issue` safe output is configured with:
- `required-title-prefix: "[refactor]"` - Only issues starting with this prefix will be closed
- `target: "*"` - Can close any issue by number (not just triggering issue)
- `max: 10` - Can close up to 10 issues in one run

To close an existing refactor issue, emit:
```
close_issue(issue_number=123, body="Closing this issue as a new semantic function refactoring analysis is being performed.")
```

**Do not proceed with analysis until all existing `[refactor]` issues are closed.**

## Task Steps

### 1. Close Existing Refactor Issues

**CRITICAL FIRST STEP**: Before performing any analysis, close existing open issues with the `[refactor]` prefix to prevent duplicate issues.

1. Use GitHub search to find open issues with `[refactor]` in the title
2. For each found issue, use `close_issue` to close it with an explanatory comment
3. Example: `close_issue(issue_number=42, body="Closing this issue as a new semantic function refactoring analysis is being performed.")`

**Do not proceed to step 2 until all existing `[refactor]` issues are closed.**

### 2. Discover Lua Source Files

Find all Lua files in the plugin source directory:

```bash
# Find all Lua files in the plugin
find lua/markdown-plus -name "*.lua" -type f | sort
```

Group files by feature module/directory to understand the organization.

### 3. Collect Function Names Per File

For each discovered Lua file:

1. Read the file contents
2. Extract all function declarations:
   - Public module functions: `function M.func_name(...)` and `M.func_name = function(...)`
   - Private functions: `local function _func_name(...)` and `local function func_name(...)`
   - Private assigned functions: `local _func_name = function(...)`
3. Create a structured inventory of:
   - File path
   - Feature module (parent directory)
   - All public function names (on `M.`)
   - All private function names (local/`_` prefixed)
   - Function signatures (parameters)

Example structure:
```
File: lua/markdown-plus/list/parser.lua
Module: list
Public Functions:
  - M.parse_list_item(line) -> ListItem|nil
  - M.get_list_type(line) -> string|nil
  - M.is_list_item(line) -> boolean
Private Functions:
  - _extract_marker(line) -> string|nil
  - _parse_indent(line) -> number
```

### 4. Semantic Clustering Analysis

Analyze the collected functions to identify patterns:

**Clustering by Naming Patterns:**
- Group functions with similar prefixes (e.g., `parse_*`, `toggle_*`, `navigate_*`, `is_*`)
- Group functions with similar suffixes (e.g., `*_line`, `*_at_cursor`, `*_in_range`)
- Identify functions that operate on the same data types or concepts
- Identify functions that share common functionality

**File Organization Rules (Lua/Neovim plugin conventions):**
- `init.lua` — module entry, setup, enable, keymap registration
- `parser.lua` — parsing and data extraction functions
- `manipulation.lua` — state-changing buffer operations
- `navigation.lua` — cursor movement and traversal
- `handlers.lua` — event handlers, insert mode behavior
- Shared helpers belong in `utils.lua` or feature-specific `shared.lua`

**Identify Outliers:**
Look for functions that don't match their file's primary purpose:
- Parsing functions in a manipulation file
- Navigation functions in a handler file
- Buffer manipulation functions in a parser file
- Helper functions scattered across multiple files instead of centralized
- Functions that duplicate logic from `utils.lua`

### 5. Duplicate Detection

For each cluster of similar functions:

1. Search for functions with similar names across files using grep:
   ```bash
   grep -rn 'function.*parse' lua/markdown-plus --include='*.lua'
   grep -rn 'function.*toggle' lua/markdown-plus --include='*.lua'
   grep -rn 'function.*navigate' lua/markdown-plus --include='*.lua'
   ```
2. Compare function implementations to identify:
   - Exact duplicates (identical implementations across files)
   - Near duplicates (similar logic with variations — e.g., same pattern matching with different patterns)
   - Functional duplicates (different implementations, same purpose — e.g., multiple ways to get cursor position)
   - Utilities that should be in `utils.lua` but are duplicated locally

### 6. Deep Reasoning Analysis

Apply deep reasoning to identify refactoring opportunities:

**Duplicate Detection Criteria:**
- Functions with >80% code similarity
- Functions with identical logic but different variable names
- Functions that perform the same operation on different data (candidates for parameterization)
- Helper functions repeated across multiple feature modules (candidates for `utils.lua`)

**Refactoring Patterns to Suggest (Lua-specific):**
- **Extract to utils.lua**: When a helper function appears in 2+ feature modules
- **Move to Appropriate Sub-module**: When a function is in the wrong file per the sub-module pattern
- **Create New Sub-module**: When a file has grown too large and contains distinct concerns
- **Parameterize**: When similar functions differ only by a pattern or config value
- **Extract Shared Module**: When 2+ features share substantial logic (like `list/shared.lua`)

### 7. Generate Refactoring Report

Create a comprehensive issue with findings:

**Report Structure:**

```markdown
# 🔧 Semantic Function Clustering Analysis

*Analysis of repository: ${{ github.repository }}*

## Executive Summary

[Brief overview of findings - total files analyzed, clusters found, outliers identified, duplicates detected]

## Function Inventory

### By Feature Module

[List of feature modules with file counts, function counts, and primary purposes]

### Clustering Results

[Summary of function clusters identified by semantic similarity]

## Identified Issues

### 1. Outlier Functions (Functions in Wrong Files)

**Issue**: Functions that don't match their file's primary purpose per the sub-module pattern

#### Example: Parsing Logic in Manipulation File

- **File**: `lua/markdown-plus/[feature]/manipulation.lua`
- **Function**: `M.parse_something(line)`
- **Issue**: Parsing function in manipulation file
- **Recommendation**: Move to `lua/markdown-plus/[feature]/parser.lua`
- **Estimated Impact**: Improved code organization, follows sub-module pattern

[... more outliers ...]

### 2. Duplicate or Near-Duplicate Functions

**Issue**: Functions with similar or identical implementations across feature modules

#### Example: Cursor Utility Duplicates

- **Occurrence 1**: `lua/markdown-plus/list/handlers.lua:_get_cursor_line()`
- **Occurrence 2**: `lua/markdown-plus/table/handlers.lua:_get_cursor_line()`
- **Similarity**: 95% code similarity
- **Code Comparison**:
  ```lua
  -- list/handlers.lua
  local function _get_cursor_line()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  end

  -- table/handlers.lua
  local function _get_cursor_line()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1]
  end
  ```
- **Recommendation**: Use `require("markdown-plus.utils").get_current_line()` if it exists, or add it to `utils.lua`
- **Estimated Impact**: Reduced duplication, single source of truth

[... more duplicates ...]

### 3. Scattered Helper Functions

**Issue**: Similar helper functions spread across multiple feature modules

**Examples**:
- `_get_indent()` in N different files
- Pattern matching helpers duplicated across parsers
- Buffer line manipulation repeated in multiple handlers

**Recommendation**: Centralize in `utils.lua` or create feature-specific `shared.lua` files
**Estimated Impact**: Centralized utilities, easier testing

### 4. Oversized Files

**Issue**: Files exceeding the project's target of 30–200 lines

[List any files >200 lines with their line counts and suggestions for splitting]

## Detailed Function Clusters

### Cluster 1: Parsing Functions

**Pattern**: `parse_*`, `is_*`, `get_*_type` functions
**Files**: [list of files]
**Functions**: [list]

**Analysis**: [Whether organization is good or needs improvement]

### Cluster 2: Navigation Functions

**Pattern**: `navigate_*`, `jump_*`, `goto_*` functions
**Files**: [list]
**Functions**: [list]

**Analysis**: [Whether organization follows the navigation sub-module pattern]

[... more clusters ...]

## Refactoring Recommendations

### Priority 1: High Impact

1. **Move Outlier Functions**
   - Move parsing functions to parser sub-modules
   - Move navigation functions to navigation sub-modules
   - Estimated effort: 1-2 hours
   - Benefits: Clearer code organization, follows established patterns

2. **Consolidate Duplicate Functions**
   - Extract shared helpers to `utils.lua`
   - Replace local duplicates with `require("markdown-plus.utils")` calls
   - Estimated effort: 1-3 hours
   - Benefits: Reduced code size, single source of truth

### Priority 2: Medium Impact

3. **Centralize Helper Functions**
   - Create or enhance `shared.lua` files within feature modules
   - Move scattered helpers to central location
   - Estimated effort: 2-4 hours
   - Benefits: Easier discoverability, reduced duplication

### Priority 3: Long-term Improvements

4. **Split Oversized Files**
   - Break files >200 lines into focused sub-modules
   - Follow the init/parser/manipulation/navigation/handlers pattern
   - Estimated effort: 2-4 hours per file
   - Benefits: Improved maintainability, easier testing

## Implementation Checklist

- [ ] Review findings and prioritize refactoring tasks
- [ ] Create detailed refactoring plan for Priority 1 items
- [ ] Move outlier functions to correct sub-modules
- [ ] Consolidate duplicate functions into `utils.lua` or `shared.lua`
- [ ] Update parent `init.lua` re-exports for backwards compatibility
- [ ] Update tests to reflect changes (`make test`)
- [ ] Verify no functionality broken
- [ ] Run linter (`make lint`) and formatter (`make format-check`)
- [ ] Consider Priority 2 and 3 items for future work

## Analysis Metadata

- **Total Lua Files Analyzed**: [count]
- **Total Functions Cataloged**: [count]
- **Function Clusters Identified**: [count]
- **Outliers Found**: [count]
- **Duplicates Detected**: [count]
- **Detection Method**: Naming pattern analysis + code comparison
- **Analysis Date**: [timestamp]
```

## Operational Guidelines

### Security
- Never execute untrusted code
- Only use read-only analysis tools
- Do not modify files during analysis (read-only mode)

### Efficiency
- Balance thoroughness with timeout constraints
- Focus on meaningful patterns, not trivial similarities
- Analyze the most impactful feature modules first (table, format, list, headers — the largest)

### Accuracy
- Verify findings before reporting
- Distinguish between acceptable local helpers and problematic duplication
- Consider Lua/Neovim idioms and this project's specific patterns
- Check if `utils.lua` already provides the function before flagging as duplicate
- Provide specific, actionable recommendations

### Issue Creation
- Only create an issue if significant findings are discovered
- Include sufficient detail for developers to understand and act
- Provide concrete examples with file paths and function signatures
- Suggest practical refactoring approaches following the project's sub-module pattern
- Focus on high-impact improvements

## Analysis Focus Areas

### High-Value Analysis
1. **Function organization by file**: Does each file follow the sub-module pattern (parser, manipulation, navigation, handlers)?
2. **Function naming patterns**: Are similar functions grouped together?
3. **Code duplication**: Are there functions that should be consolidated in `utils.lua`?
4. **Utility scatter**: Are helper functions properly centralized?

### What to Report
- Functions clearly in the wrong sub-module (e.g., parsing functions in manipulation file)
- Duplicate implementations of the same functionality across feature modules
- Scattered helper functions that should be in `utils.lua`
- Opportunities for improved code organization following the established pattern
- Files exceeding 200 lines that could be split

### What to Skip
- Minor naming inconsistencies within a single file
- Single-occurrence patterns
- Lua-specific idioms (the `local M = {}` pattern itself, `pcall` wrappers, etc.)
- Spec files (already excluded)
- Trivial helper functions (<5 lines) that are only used once in their file
- Private functions that are clearly file-scoped utilities

## Success Criteria

This analysis is successful when:
1. ✅ All Lua files in `lua/markdown-plus/` are analyzed
2. ✅ Function names and signatures are collected and organized
3. ✅ Semantic clusters are identified based on naming and purpose
4. ✅ Outliers (functions in wrong sub-modules) are detected
5. ✅ Duplicates are identified through code comparison
6. ✅ Concrete refactoring recommendations are provided following the project's patterns
7. ✅ A detailed issue is created with actionable findings

**Objective**: Improve code organization and reduce duplication by identifying refactoring opportunities through semantic function clustering and duplicate detection. Focus on high-impact, actionable findings that follow the project's established sub-module pattern.
