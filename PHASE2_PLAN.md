# Phase 2 Refactoring Plan: Split Large Modules

**Date:** October 29, 2024  
**Branch:** `refactor/phase2-split-large-modules`  
**Goal:** Split large monolithic init.lua files into focused, maintainable sub-modules

---

## Current State

| Module | Lines | Status |
|--------|-------|--------|
| `headers/init.lua` | 1019 | 🔴 **Too large** - needs splitting |
| `list/init.lua` | 918 | 🔴 **Too large** - needs splitting |
| `links/init.lua` | 448 | 🟡 **Borderline** - could benefit |
| `format/init.lua` | 369 | 🟢 **Good** - no action needed |
| `quote/init.lua` | 75 | 🟢 **Good** - no action needed |

**Target:** Files should be 200-300 lines max for optimal maintainability

---

## Phase 2.1: Split Headers Module (1019 lines → ~150-200 per file)

### Current Structure Analysis

The headers module has 6 distinct functional areas:
1. Navigation (3 functions, ~70 lines)
2. Parsing (2 functions, ~40 lines) 
3. Manipulation (3 functions, ~80 lines)
4. Slug generation (1 function, ~30 lines)
5. TOC generation (3 functions, ~380 lines) **← LARGEST**
6. TOC window (1 function, ~100 lines)

### Proposed File Structure

```
lua/markdown-plus/headers/
├── init.lua              (~150 lines) - Setup, config, public API
├── parser.lua            (~80 lines)  - parse_header, get_all_headers, generate_slug
├── navigation.lua        (~100 lines) - next_header, prev_header, follow_link
├── manipulation.lua      (~120 lines) - promote_header, demote_header, set_header_level
├── toc.lua              (~380 lines) - generate_toc, find_toc, update_toc
└── toc_window.lua       (~150 lines) - open_toc_window, window management
```

### Migration Strategy

**Step 1: Create Sub-modules**
1. Create `parser.lua` - Move parsing & slug functions
2. Create `navigation.lua` - Move navigation functions
3. Create `manipulation.lua` - Move header level functions
4. Create `toc.lua` - Move TOC generation/update logic
5. Create `toc_window.lua` - Move window management

**Step 2: Update init.lua**
- Keep: setup(), enable(), setup_keymaps()
- Expose: Re-export public functions from sub-modules
- Remove: Move implementation details to sub-modules

**Step 3: Update Tests**
- Tests should still import from `headers` module
- Internal tests can directly test sub-modules
- No breaking changes to public API

---

## Phase 2.2: Split List Module (918 lines → ~150-200 per file)

### Current Structure Analysis

The list module has 4 distinct functional areas:
1. Parsing (4 functions, ~120 lines)
2. Navigation/Input Handlers (6 functions, ~380 lines) **← LARGEST**
3. Renumbering (4 functions, ~160 lines)
4. Checkboxes (8 functions, ~200 lines)

### Proposed File Structure

```
lua/markdown-plus/list/
├── init.lua              (~120 lines) - Setup, config, public API
├── parser.lua            (~150 lines) - parse_list_line, is_empty_list_item, etc.
├── handlers.lua          (~400 lines) - handle_enter, handle_tab, handle_backspace, etc.
├── renumber.lua          (~180 lines) - renumber_ordered_lists, find_list_groups, etc.
└── checkbox.lua          (~220 lines) - All checkbox management functions
```

### Migration Strategy

**Step 1: Create Sub-modules**
1. Create `parser.lua` - Move parsing & utility functions
2. Create `handlers.lua` - Move input handling functions
3. Create `renumber.lua` - Move renumbering logic
4. Create `checkbox.lua` - Move checkbox functions

**Step 2: Update init.lua**
- Keep: setup(), enable(), setup_keymaps(), setup_renumber_autocmds()
- Expose: Re-export public functions from sub-modules
- Remove: Move implementation to sub-modules

**Step 3: Update Tests**
- Tests continue to import from `list` module
- No breaking changes to public API

---

## Phase 2.3: Consider Links Module (448 lines)

### Analysis

The links module is borderline. Options:

**Option A: Leave As-Is** (Recommended for Phase 2)
- 448 lines is manageable
- Already has clear separation of concerns
- Low complexity within functions

**Option B: Split Later** (Phase 3 if needed)
```
lua/markdown-plus/links/
├── init.lua              (~150 lines) - Setup, keymaps, public API
├── parser.lua            (~120 lines) - get_link_at_cursor, find_reference_url
├── operations.lua        (~180 lines) - insert_link, edit_link, convert_*
```

**Recommendation:** Skip for Phase 2, reassess in Phase 3

---

## Implementation Order

### Priority 1: Headers Module (Highest Impact)
- **Lines saved:** ~100 (split overhead)
- **Maintainability:** High improvement
- **Complexity:** Medium (TOC logic is complex)
- **Estimate:** 3-4 hours

### Priority 2: List Module (High Impact)
- **Lines saved:** ~80 (split overhead)
- **Maintainability:** High improvement
- **Complexity:** Medium (checkbox + renumber logic)
- **Estimate:** 3-4 hours

### Priority 3: Links Module (Optional)
- **Lines saved:** ~30 (split overhead)
- **Maintainability:** Low-medium improvement
- **Complexity:** Low
- **Estimate:** 1-2 hours (if needed)

---

## Best Practices to Follow

### 1. Module Organization

**init.lua should only contain:**
- Module setup and configuration
- Public API exposure
- Keymap definitions
- Sub-module loading

**Sub-modules should:**
- Be focused on single responsibility
- Have clear, descriptive names
- Export only what's needed
- Keep internal helpers local

### 2. API Design

```lua
-- init.lua - Public API
local M = {}
local parser = require("markdown-plus.headers.parser")
local navigation = require("markdown-plus.headers.navigation")

-- Expose sub-module functions
M.parse_header = parser.parse_header
M.next_header = navigation.next_header

return M
```

### 3. Testing Strategy

```lua
-- Tests continue to use main module
local headers = require("markdown-plus.headers")
headers.parse_header(...) -- Works!

-- Or test sub-modules directly for internals
local parser = require("markdown-plus.headers.parser")
parser.parse_header(...) -- Also works!
```

### 4. No Breaking Changes

- All existing `require()` paths stay the same
- All public functions remain accessible
- Only internal organization changes

---

## Success Criteria

✅ **Code Organization**
- No file exceeds 300 lines
- Each file has single, clear responsibility
- Related functions are grouped together

✅ **Maintainability**
- Easy to find specific functionality
- Clear module boundaries
- Reduced cognitive load

✅ **Testing**
- All existing tests pass unchanged
- New tests can target sub-modules
- Coverage maintained or improved

✅ **Documentation**
- Sub-modules have clear docstrings
- API remains well-documented
- Internal helpers are commented

✅ **Performance**
- No measurable performance regression
- Lazy loading where appropriate
- Module initialization is fast

---

## Risks & Mitigation

### Risk 1: Circular Dependencies
**Mitigation:** 
- Careful dependency analysis before splitting
- Use dependency injection where needed
- Keep shared utilities in separate files

### Risk 2: Breaking Tests
**Mitigation:**
- Run tests after each sub-module creation
- Maintain public API unchanged
- Add integration tests

### Risk 3: Over-splitting
**Mitigation:**
- Target 200-300 lines per file
- Keep related functions together
- Don't split if it adds complexity

---

## Timeline

**Total Estimate:** 6-10 hours

- **Phase 2.1 (Headers):** 3-4 hours
- **Phase 2.2 (List):** 3-4 hours  
- **Phase 2.3 (Links):** 1-2 hours (if needed)
- **Testing & Polish:** 1-2 hours

---

## Next Steps After Phase 2

**Phase 3 Candidates:**
1. Add pattern matching library (reduce regex duplication)
2. Add health check module
3. Consider async/job control module
4. Performance profiling and optimization

**Phase 4: Documentation**
1. Auto-generate module docs
2. Add architecture diagrams
3. Create contributor guides

---

**Ready to Start Phase 2!**
