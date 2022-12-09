local utils = require "tests.utils"
local lsp_assert = require "tests.lsp_asserts"
local methods = require("typescript-tools.protocol.constants").LspMethods

describe("Lsp request", function()
  it("should return correct response for " .. methods.Hover, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Hover, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(3, 8),
    })

    local result = lsp_assert.response(ret)
    assert.is.True(#result.contents >= 1)
    assert.are.same(result.contents[1].value, "const foo: 1")
    lsp_assert.range(result.range, 3, 8, 3, 11)
  end)

  it("should return correct response for " .. methods.Reference, function()
    utils.open_file "src/other.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Reference, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 13),
    })

    local result = lsp_assert.response(ret)
    assert.are.same(#result, 4)
  end)

  it("should return correct response for " .. methods.Definition, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Definition, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(10, 0),
    })

    local result = lsp_assert.response(ret)
    assert.are.same(#result, 1)
    lsp_assert.range(result[1].range, 2, 9, 2, 13)
  end)

  it("should return correct response for " .. methods.TypeDefinition, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.TypeDefinition, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(7, 10),
    })

    local result = lsp_assert.response(ret)
    assert.are.same(#result, 1)
    assert.has.match(".+/lib%.dom%.d%.ts", result[1].uri)
  end)

  it("should return correct response for " .. methods.Implementation, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Implementation, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(5, 2),
    })

    local result = lsp_assert.response(ret)
    assert.are.same(#result, 1)
    assert.has.match(".+/src/other%.ts", result[1].uri)
    lsp_assert.range(result[1].range, 0, 13, 0, 22)
  end)

  it("should return correct response for " .. methods.Rename, function()
    utils.open_file "src/other.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Rename, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(2, 0),
      newName = "testRename",
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result.changes)

    local keys = vim.tbl_keys(result.changes)
    table.sort(keys)
    assert.has.match(".+/src/index%.ts", keys[1])
    assert.are.same(#result.changes[keys[1]], 2)
    assert.has.match(".+/src/other%.ts", keys[2])
    assert.are.same(#result.changes[keys[2]], 2)
  end)

  it("should return correct response for " .. methods.Completion, function()
    utils.open_file "src/completion.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Completion, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 8),
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result.items)

    local items = result.items
    assert.is.True(#items >= 20)

    local completions = vim.tbl_map(function(it)
      return it.label
    end, items)
    table.sort(completions)

    assert.are.same(completions[1], "assert")
    assert.are.same(completions[#completions], "warn")
  end)

  it("should return correct response for " .. methods.CompletionResolve, function()
    utils.open_file "src/completion.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.CompletionResolve, {
      commitCharacters = { "(" },
      data = {
        character = 8,
        entryNames = { "warn" },
        file = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. "/completion.ts",
        line = 0,
      },
      filterText = "warn",
      insertText = "warn",
      insertTextFormat = 1,
      kind = 2,
      label = "warn",
      sortText = "11",
    })

    local result = lsp_assert.response(ret)
    assert.is.table(result)
    assert.are.same(result.detail, "(method) Console.warn(...data: any[]): void")
  end)

  it("should return correct response for " .. methods.SignatureHelp, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.SignatureHelp, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(7, 14),
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result.signatures)

    local signatures = result.signatures
    assert.is.same(#signatures, 1)

    assert.is.table(signatures[1])
    assert.are.same(signatures[1].label, "log(...data: any[]): void")
  end)
end)
