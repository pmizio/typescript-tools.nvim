local utils = require "tests.utils"
local lsp_assert = require "tests.lsp_asserts"
local methods = require("typescript-tools.protocol.constants").LspMethods

describe("Lsp request", function()
  it("should return correct response for " .. methods.Hover, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Hover, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(1, 8),
    })

    assert.are.same(#ret, 1)

    local result = ret[1].result
    assert.is.True(#result.contents >= 1)
    assert.are.same(result.contents[1].value, "const foo: 1")
    lsp_assert.range(result.range, 1, 8, 1, 11)
  end)
end)
