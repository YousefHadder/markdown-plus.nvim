-- Driver for the end-to-end keymap scenarios in test/e2e/cases.lua.
--
-- Run via scripts/run-e2e.sh, which supplies the isolated config and temp XDG dirs.
-- Every case gets a brand-new scratch buffer backed by a real .md path so the FileType
-- autocmd fires and the plugin installs its buffer-local keymaps, exactly as for a user.
-- Keys are fed with the "x" flag, which processes the typeahead synchronously, so the run
-- is deterministic: no sleeps, no polling, no dependence on machine speed.

local root = os.getenv("MARKDOWN_PLUS_ROOT") or vim.fn.getcwd()
local cases = dofile(root .. "/test/e2e/cases.lua")

local GREEN, RED, DIM, RESET = "\27[32m", "\27[31m", "\27[2m", "\27[0m"
local results = { passed = 0, failed = 0, failures = {} }

---Render a list of lines so trailing whitespace is visible in the report.
---The bug under test turns on exact trailing characters, so "- [x] " and "- [x]" must not
---look identical in the output.
---@param lines string[]
---@return string
local function show(lines)
  local parts = {}
  for i, line in ipairs(lines) do
    parts[i] = string.format("%q", line)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

---Run one scenario in a fresh buffer and record the outcome.
---@param case markdown-plus.e2e.Case
---@param index number
---@return nil
local function run_case(case, index)
  local path = string.format("%s/e2e-%03d.md", vim.fn.tempname(), index)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

  vim.cmd("silent! edit " .. vim.fn.fnameescape(path))
  vim.bo.filetype = "markdown"

  -- Pin indentation *after* the filetype is set: Neovim's bundled markdown ftplugin sets
  -- shiftwidth=4 on FileType, which would otherwise decide how far <Tab> indents and make
  -- these assertions depend on the shipped runtime rather than on the plugin.
  vim.bo.shiftwidth = 2
  vim.bo.tabstop = 2
  vim.bo.expandtab = true

  vim.api.nvim_buf_set_lines(0, 0, -1, false, case.lines)
  local cursor = case.cursor or { 1, 0 }
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)

  local keys = vim.api.nvim_replace_termcodes(case.keys, true, false, true)
  local ok, err = pcall(vim.api.nvim_feedkeys, keys, "mx", false)

  -- Leave insert mode and drain anything a handler queued, so one case cannot bleed into
  -- the next through the typeahead.
  pcall(vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local matched = ok and vim.deep_equal(actual, case.expected)

  if matched then
    results.passed = results.passed + 1
    io.write(string.format("%s  PASS%s  [%s] %s\n", GREEN, RESET, case.priority, case.name))
  else
    results.failed = results.failed + 1
    table.insert(results.failures, case.name)
    io.write(string.format("%s  FAIL%s  [%s] %s\n", RED, RESET, case.priority, case.name))
    io.write(string.format("        keys      %s\n", case.keys))
    io.write(string.format("        expected  %s\n", show(case.expected)))
    io.write(string.format("        actual    %s\n", show(actual)))
    if not ok then
      io.write(string.format("        error     %s\n", tostring(err)))
    end
  end

  vim.cmd("silent! bwipeout!")
end

io.write("\nmarkdown-plus end-to-end keymap tests\n")
io.write(string.rep("-", 72) .. "\n")
io.write(string.format("%snvim       %s%s\n", DIM, tostring(vim.version()), RESET))
io.write(string.format("%splugin     %s%s\n", DIM, os.getenv("MARKDOWN_PLUS_ROOT") or vim.fn.getcwd(), RESET))
io.write(string.format("%sXDG_CONFIG %s%s\n", DIM, tostring(os.getenv("XDG_CONFIG_HOME")), RESET))
io.write(string.rep("-", 72) .. "\n")

for index, case in ipairs(cases) do
  run_case(case, index)
end

io.write(string.rep("-", 72) .. "\n")
io.write(string.format("passed %d   failed %d   total %d\n", results.passed, results.failed, #cases))

if results.failed > 0 then
  io.write("\nfailed cases:\n")
  for _, name in ipairs(results.failures) do
    io.write("  - " .. name .. "\n")
  end
  vim.cmd("cquit 1")
end

vim.cmd("quitall!")
