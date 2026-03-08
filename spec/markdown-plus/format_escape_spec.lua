describe("markdown-plus format escape", function()
  local escape = require("markdown-plus.format.escape")

  it("escapes ASCII punctuation for markdown literals", function()
    local escaped = escape.escape_markdown("Hello *world* [link](url)!")
    assert.are.equal("Hello \\*world\\* \\[link\\]\\(url\\)\\!", escaped)
  end)

  it("does not double-escape already escaped punctuation", function()
    local escaped = escape.escape_markdown("\\*already\\* and *new*")
    assert.are.equal("\\*already\\* and \\*new\\*", escaped)
  end)

  it("unescapes escaped markdown punctuation", function()
    local unescaped = escape.unescape_markdown("\\*world\\* \\[link\\]\\(url\\)")
    assert.are.equal("*world* [link](url)", unescaped)
  end)

  it("escapes standalone backslashes", function()
    local escaped = escape.escape_markdown("path\\to\\file")
    assert.are.equal("path\\\\to\\\\file", escaped)
  end)
end)
