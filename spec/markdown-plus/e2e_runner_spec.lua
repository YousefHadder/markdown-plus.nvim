---@diagnostic disable: undefined-field
describe("e2e runner fixture isolation", function()
  ---Run the actual driver in a clean child Neovim with synthetic cases.
  ---@param fixture string Lua source returning the cases
  ---@return integer status
  ---@return string output
  local function run(fixture)
    local root = vim.fn.getcwd()
    local injection = string.format(
      "lua local read = dofile; dofile = function(path) if path == %q then %s end return read(path) end",
      root .. "/test/e2e/cases.lua",
      fixture
    )
    local output = vim.fn.system({
      vim.v.progpath,
      "--clean",
      "--headless",
      "-u",
      root .. "/test/e2e/init.lua",
      "-c",
      injection,
      "-l",
      root .. "/test/e2e/runner.lua",
    })
    return vim.v.shell_error, output
  end

  it("fails with a diagnostic when setup throws even if the buffer matches", function()
    local status, output = run([[
      return {
        {
          name = "broken setup", priority = "P0", lines = { "unchanged" }, keys = "",
          expected = { "unchanged" },
          setup = function() error("injected setup failure") end,
        },
      }
    ]])
    assert.are.equal(1, status, output)
    assert.is_not_nil(output:find("injected setup failure", 1, true), output)
    assert.is_not_nil(output:find("passed 0   failed 1", 1, true), output)
  end)

  it("restores a replaced global callback mapping between cases", function()
    local status, output = run([[
      vim.keymap.set("i", "<A-CR>", function() return "ORIGINAL" end, { expr = true })
      return {
        {
          name = "rival", priority = "P0", lines = { "plain" }, keys = "A<A-CR><Esc>",
          expected = { "plainRIVAL" },
          setup = function() vim.keymap.set("i", "<A-CR>", "RIVAL") end,
        },
        {
          name = "restored", priority = "P0", lines = { "plain" }, keys = "A<A-CR><Esc>",
          expected = { "plainORIGINAL" },
        },
      }
    ]])
    assert.are.equal(0, status, output)
    assert.is_not_nil(output:find("passed 2   failed 0", 1, true), output)
  end)

  it("removes a newly installed mapping even when setup fails", function()
    local status, output = run([[
      local before = vim.fn.maparg("<F12>", "i", false, true)
      return {
        {
          name = "partial setup", priority = "P0", lines = { "plain" }, keys = "",
          expected = { "plain" },
          setup = function()
            vim.keymap.set("i", "<F12>", "LEAK")
            error("partial setup failed")
          end,
        },
        {
          name = "no leak", priority = "P0", lines = { "plain" }, keys = "",
          expected = { "plain" },
          setup = function()
            assert(vim.deep_equal(before, vim.fn.maparg("<F12>", "i", false, true)), "fixture leaked")
          end,
        },
      }
    ]])
    assert.are.equal(1, status, output)
    assert.is_not_nil(output:find("passed 1   failed 1", 1, true), output)
    assert.is_nil(output:find("fixture leaked", 1, true), output)
  end)
end)
