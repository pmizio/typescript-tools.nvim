local utils = require "tests.utils"
local lsp_assert = require "tests.lsp_asserts"
local methods = require("typescript-tools.protocol.constants").LspMethods
local customMethods = require("typescript-tools.protocol.constants").CustomMethods

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

  it("should return correct response for " .. methods.Formatting, function()
    utils.open_file "src/formatting.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Formatting, {
      textDocument = utils.get_text_document(),
    })

    local result = lsp_assert.response(ret)

    assert.is.same(#result, 5)
  end)

  it("should return correct response for " .. methods.RangeFormatting, function()
    utils.open_file "src/formatting.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.RangeFormatting, {
      textDocument = utils.get_text_document(),
      range = utils.make_range(2, 0, 2, 50),
    })

    local result = lsp_assert.response(ret)

    assert.is.same(
      #result,
      utils.tsv {
        ["4.0"] = 2,
        ["4.1"] = 2,
        ["4.2"] = 2,
        ["4.3"] = 2,
        ["4.4"] = 2,
        ["4.5"] = 2,
        default = 3,
      }
    )
  end)

  it("should return correct response for " .. methods.WorkspaceSymbol, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.WorkspaceSymbol, {
      query = "exampleFn",
    })

    local result = lsp_assert.response(ret)

    assert.is.same(#result, 1)
    lsp_assert.range(result[1].location.range, 0, 13, 0, 33)
  end)

  it("should return correct response for " .. methods.PrepareCallHierarchy, function()
    utils.open_file "src/other.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.PrepareCallHierarchy, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 13),
    })

    local result = lsp_assert.response(ret)

    assert.is.same(#result, 1)
    assert.is.same(result[1].name, "exampleFn")
  end)

  it("should return correct response for " .. methods.IncomingCalls, function()
    utils.open_file "src/other.ts"
    utils.wait_for_lsp_initialization()

    -- INFO: PrepareCallHierarchy request is required to get incomming calls
    local call_hierarchy = vim.lsp.buf_request_sync(0, methods.PrepareCallHierarchy, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 13),
    })
    local call_hierarchy_item = lsp_assert.response(call_hierarchy)[1]
    local ret = vim.lsp.buf_request_sync(0, methods.IncomingCalls, {
      textDocument = utils.get_text_document(),
      item = call_hierarchy_item,
    })

    local result = lsp_assert.response(ret)

    assert.is.same(#result, 2)

    local call_uris = vim.tbl_map(function(it)
      return it.from.uri
    end, result)
    table.sort(call_uris)

    assert.has.match(".+/src/index%.ts", call_uris[1])
    assert.has.match(".+/src/other%.ts", call_uris[2])
  end)

  it("should return correct response for " .. methods.OutgoingCalls, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    -- INFO: PrepareCallHierarchy request is required to get outgoing calls
    local call_hierarchy = vim.lsp.buf_request_sync(0, methods.PrepareCallHierarchy, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(2, 9),
    })
    local call_hierarchy_item = lsp_assert.response(call_hierarchy)[1]
    local ret = vim.lsp.buf_request_sync(0, methods.OutgoingCalls, {
      textDocument = utils.get_text_document(),
      item = call_hierarchy_item,
    })

    local result = lsp_assert.response(ret)

    assert.is.same(#result, 2)

    local call_uris = vim.tbl_map(function(it)
      return it.to.uri
    end, result)
    table.sort(call_uris)

    assert.has.match(".+/lib%.dom%.d%.ts", call_uris[1])
    assert.has.match(".+/src/other%.ts", call_uris[2])
  end)

  it("should return correct response for " .. methods.WillRenameFiles, function()
    utils.open_file "src/imported.ts"
    utils.wait_for_lsp_initialization()

    local oldUri = "file://" .. vim.fn.getcwd() .. "/src/other.ts"
    local newUri = "file://" .. vim.fn.getcwd() .. "/src/other2.ts"
    local ret = vim.lsp.buf_request_sync(0, methods.WillRenameFiles, {
      files = {
        {
          oldUri = oldUri,
          newUri = newUri,
        },
      },
    })

    local result = lsp_assert.response(ret)
    local changes = result.changes

    assert.is.table(changes)

    local uriWithChangedImport = "file://" .. vim.fn.getcwd() .. "/src/index.ts"
    local fileTextEdits = changes[uriWithChangedImport]

    assert.is.table(fileTextEdits)
    assert.is.same(1, #fileTextEdits)
    assert.are.same("./other2", fileTextEdits[1].newText)
  end)

  it("should return correct response for " .. methods.FoldingRange, function()
    utils.open_file "src/folding.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.FoldingRange, {
      textDocument = utils.get_text_document(),
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result)
    print([[[requests_spec.lua:330] -- result: ]] .. vim.inspect(result))

    local import_range = result[1]

    assert.is.same(0, import_range.startLine)
    assert.is.same(1, import_range.endLine)
    assert.is.same("imports", import_range.kind)

    local comment_range = result[2]

    assert.is.same(3, comment_range.startLine)
    assert.is.same(5, comment_range.endLine)
    assert.is.same("region", comment_range.kind)

    local bracketRange = result[3]

    assert.is.same(8, bracketRange.startLine)
    assert.is.same(9, bracketRange.endLine)
    assert.is.same(nil, bracketRange.kind)
  end)
  
  it("should return correct response for " .. methods.DocumentSymbol, function()
    utils.open_file "src/imported.ts"
    utils.wait_for_lsp_initialization()

    local uri = "file://" .. vim.fn.getcwd() .. "/src/index.ts"
    local ret = vim.lsp.buf_request_sync(0, methods.DocumentSymbol, {
      textDocument = {
        uri = uri,
      },
    })
    local result = lsp_assert.response(ret)

    assert.is.table(result)

    assert.is.same(1, #result)
    assert.is.same("main", result[1].name)
    assert.is.table(result[1].children)
    assert.is.same(1, #result[1].children)
    assert.is.same("foo", result[1].children[1].name)
    assert.is.table(result[1].children[1].children)
    assert.is.same(0, #result[1].children[1].children)
  end)

  it("should return correct response for " .. customMethods.OrganizeImports, function()
    utils.open_file "src/imported.ts"
    utils.wait_for_lsp_initialization()

    local file = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. "/imports.ts"
    local ret = vim.lsp.buf_request_sync(0, customMethods.OrganizeImports, {
      file = file,
      mode = "All",
    })
    local result = lsp_assert.response(ret)
    local changes = result.changes

    assert.is.table(changes)

    local uriWithChangedImport = "file://" .. vim.fn.getcwd() .. "/src/imports.ts"
    local fileTextEdits = changes[uriWithChangedImport]

    assert.is.table(fileTextEdits)
    assert.is.same(1, #fileTextEdits)
    assert.are.same("import { export1 } from './exports'\n", fileTextEdits[1].newText)
  end)
end)
