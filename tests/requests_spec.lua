local utils = require "tests.utils"
local lsp_assert = require "tests.lsp_asserts"
local mocks = require "tests.mocks"
local plugin_config = require "typescript-tools.config"
local c = require "typescript-tools.protocol.constants"
local methods = c.LspMethods
local custom_methods = c.CustomMethods
local v = vim.version

describe("Lsp request", function()
  after_each(function()
    -- INFO: close all buffers
    _G.file_closed = false
    _G.initial_diagnostics_emitted = false
    vim.cmd "silent 1,$bd!"
    utils.wait_for_lsp_did_close()
  end)

  it("should return correct response for " .. methods.Hover, function()
    utils.open_file "src/index.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Hover, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(3, 8),
    })

    local result = lsp_assert.response(ret)
    assert.is.True(#result.contents >= 1)
    assert.are.same(result.contents[1].value, "```typescript\nconst foo: 1\n```\n")
    lsp_assert.range(result.range, 3, 8, 3, 11)
  end)

  it("should return correct response for " .. methods.Reference, function()
    utils.open_file "src/other.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.Reference, {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 13),
      context = { includeDeclaration = true },
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
    lsp_assert.range(result[1].targetSelectionRange, 2, 9, 2, 13)
  end)

  it(
    "should return correct response for " .. methods.Definition .. " - source definition",
    function()
      local version = v.parse(vim.env.TEST_TYPESCRIPT_VERSION)
      if version and v.lt(version, { 4, 7 }) then
        return
      end
      utils.open_file "src/index.ts"
      utils.wait_for_lsp_initialization()

      local ret = vim.lsp.buf_request_sync(0, methods.Definition, {
        textDocument = utils.get_text_document(),
        position = utils.make_position(10, 0),
        context = { source_definition = true },
      })

      local result = lsp_assert.response(ret)
      assert.are.same(#result, 1)
      lsp_assert.range(result[1].targetSelectionRange, 2, 9, 2, 13)
    end
  )

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

    local req = {
      textDocument = utils.get_text_document(),
      position = utils.make_position(0, 8),
    }
    local ret = vim.lsp.buf_request_sync(0, methods.Completion, req)

    local result = lsp_assert.response(ret)

    assert.is.table(result.items)

    local items = result.items
    assert.is.True(#items >= 20)

    local completions = vim.tbl_map(function(it)
      if it.kind == c.CompletionItemKind.Method or it.kind == c.CompletionItemKind.Function then
        assert.are.same(it.insertTextFormat, c.InsertTextFormat.PlainText)
      end
      return it.label
    end, items)
    table.sort(completions)

    assert.are.same(completions[1], "assert")
    assert.are.same(completions[#completions], "warn")

    -- same test as above but with function snippets enabled
    local prev_config = plugin_config.complete_function_calls
    plugin_config.complete_function_calls = true

    ret = vim.lsp.buf_request_sync(0, methods.Completion, req)
    result = lsp_assert.response(ret)
    assert.is.table(result.items)

    items = result.items
    assert.is.True(#items >= 20)

    completions = vim.tbl_map(function(it)
      if it.kind == c.CompletionItemKind.Method or it.kind == c.CompletionItemKind.Function then
        assert.are.same(it.insertTextFormat, c.InsertTextFormat.Snippet)
      end
      return it.label
    end, items)
    table.sort(completions)

    assert.are.same(completions[1], "assert(...)")
    assert.are.same(completions[#completions], "warn(...)")

    plugin_config.complete_function_calls = prev_config
  end)

  it(
    "should return correct response for " .. methods.Completion .. " at dot member access",
    function()
      utils.open_file "src/completion.ts"
      utils.wait_for_lsp_initialization()

      local req = {
        textDocument = utils.get_text_document(),
        position = utils.make_position(1, 3),
      }
      local ret = vim.lsp.buf_request_sync(0, methods.Completion, req)

      local result = lsp_assert.response(ret)

      assert.is.table(result.items)

      local completion = result.items[1]

      assert.are.same(completion.filterText, ".concat")
      assert.are.same(completion.insertText, ".concat")
      assert.are.same(completion.textEdit, {
        insert = {
          ["end"] = {
            character = 3,
            line = 1,
          },
          start = {
            character = 2,
            line = 1,
          },
        },
        newText = ".concat",
        replace = {
          ["end"] = {
            character = 3,
            line = 1,
          },
          start = {
            character = 2,
            line = 1,
          },
        },
      })
    end
  )

  it("should return correct response for " .. methods.CompletionResolve, function()
    utils.open_file "src/completion.ts"
    utils.wait_for_lsp_initialization()

    local req = {
      commitCharacters = { "(" },
      data = {
        character = 8,
        entryNames = { "warn" },
        file = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. "/completion.ts",
        line = 0,
      },
      filterText = "warn",
      insertText = "warn",
      insertTextFormat = c.InsertTextFormat.PlainText,
      kind = c.CompletionItemKind.Function,
      label = "warn",
      sortText = "11",
    }
    local ret = vim.lsp.buf_request_sync(0, methods.CompletionResolve, req)

    local result = lsp_assert.response(ret)
    assert.is.table(result)
    assert.are.same(result.insertText, "warn")
    assert.are.same(result.detail, "(method) Console.warn(...data: any[]): void")

    -- same test as above but with function snippets enabled
    local prev_config = plugin_config.complete_function_calls
    plugin_config.complete_function_calls = true

    req.label = "warn(...)"
    req.insertTextFormat = c.InsertTextFormat.Snippet
    ret = vim.lsp.buf_request_sync(0, methods.CompletionResolve, req)
    result = lsp_assert.response(ret)

    assert.is.table(result)
    assert.are.same(result.insertText, "warn($0)")
    assert.are.same(result.detail, "(method) Console.warn(...data: any[]): void")

    plugin_config.complete_function_calls = prev_config
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

    local import_range = result[1]

    assert.is.same(0, import_range.startLine)
    assert.is.same(1, import_range.endLine)
    assert.is.same("imports", import_range.kind)

    local comment_range = result[2]

    assert.is.same(3, comment_range.startLine)
    assert.is.same(5, comment_range.endLine)
    assert.is.same("region", comment_range.kind)

    local bracketRange = result[3]

    assert.is.same(7, bracketRange.startLine)
    assert.is.same(8, bracketRange.endLine)
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

  it("should return correct response for " .. custom_methods.OrganizeImports, function()
    utils.open_file "src/imported.ts"
    utils.wait_for_lsp_initialization()

    local file = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. "/imports.ts"
    local ret = vim.lsp.buf_request_sync(0, custom_methods.OrganizeImports, {
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
    assert.are.same("import { export1 } from './exports';\n", fileTextEdits[1].newText)
  end)

  it("should return correct response for " .. methods.CodeAction, function()
    utils.open_file "src/code_actions.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.CodeAction, {
      textDocument = utils.get_text_document(),
      range = utils.make_range(1, 0, 1, 0),
      context = mocks.mocked_code_action_context,
    })

    local result = lsp_assert.response(ret)

    local version = v.parse(vim.env.TEST_TYPESCRIPT_VERSION)

    -- INFO: TS 4.2 return completly different response than other versions IDK why,
    -- maybe it's a bug of this version
    if utils.is_typescript_version "4.2" then
      assert.is.same(2, #result)
      assert.is.same(result[1].title, "Infer function return type")
      assert.is.same(result[2].title, "Remove variable statement")
    elseif version and v.gt(version, { 5, 1 }) then
      assert.is.same(2, #result)
      assert.is.same(result[1].title, "Move to a new file")
      assert.is.same(result[2].title, "Remove variable statement")
    else
      assert.is.same(1, #result)
      assert.is.same(result[1].title, "Remove variable statement")
    end
  end)

  it("should return correct response for " .. methods.CodeActionResolve, function()
    utils.open_file "src/code_actions.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.CodeActionResolve, {
      kind = c.CodeActionKind.SourceOrganizeImports,
      data = {
        scope = {
          type = "file",
          args = { file = vim.fn.getcwd() .. "/src/code_actions.ts" },
        },
        skipDestructiveCodeActions = false,
      },
    })

    local result = lsp_assert.response(ret)
    assert.is.table(result.edit)
    assert.is.table(result.edit.changes)
  end)

  it("should return correct response for " .. custom_methods.Diagnostic, function()
    utils.open_file "src/diagnostic1.ts"
    utils.open_file("src/diagnostic2.ts", "vs")
    utils.wait_for_lsp_initialization()
    utils.wait_for_initial_diagnostics()

    local f1 = vim.uri_from_fname(vim.fn.getcwd() .. "/src/diagnostic1.ts")
    local f2 = vim.uri_from_fname(vim.fn.getcwd() .. "/src/diagnostic2.ts")

    local ret = vim.lsp.buf_request_sync(0, custom_methods.Diagnostic, {
      textDocument = { uri = f1 },
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result.relatedDocuments)

    result = result.relatedDocuments

    assert.is.same(2, #vim.tbl_values(result))

    local f1_items = result[f1].items
    local f2_items = result[f2].items

    assert.is.same(1, #f1_items)
    assert.is.same(2, #f2_items)
    assert.is.same(f1_items[1].message, "Type 'number' is not assignable to type 'string'.")
    assert.is.same(f2_items[1].message, "Type 'string' is not assignable to type 'number'.")
    assert.is.same(f2_items[2].message, "'num' is declared but its value is never read.")
  end)

  it("should return correct response for " .. methods.SemanticTokensFull, function()
    utils.open_file "src/semanticTokens.ts"
    utils.wait_for_lsp_initialization()

    if not utils.supports_capability "semanticTokensProvider" then
      utils.print_skip "semanticTokensProvider not supported in typescript version below 4.1"
      return
    end

    local ret = vim.lsp.buf_request_sync(0, methods.SemanticTokensFull, {
      textDocument = utils.get_text_document(),
    })
    local result = lsp_assert.response(ret)
    local data = result.data

    assert.is.table(data)
    -- stylua: ignore
    assert.is.same(data,
       { 0, 6, 6, 7, 9, 1, 6, 1, 7, 9, 2, 9, 4, 10, 1, 0, 5, 5, 6, 1, 0, 15, 6, 6, 1, 1, 9, 5, 6, 0, 0, 8, 6, 6, 0, 0, 9, 1, 7, 8 }
    )
  end)

  it("should return correct response for " .. methods.InlayHint, function()
    utils.open_file "src/inlayHints.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.InlayHint, {
      textDocument = utils.get_text_document(),
      range = utils.make_range(0, 0, 9, 21),
    })

    if not utils.supports_capability "inlayHintProvider" then
      utils.print_skip "inlayHintsProvider not supported in typescript version below 4.4"
      return
    end

    local result = lsp_assert.response(ret)

    assert.is.table(result)
    assert.is.same(#result, 3)
    assert.is.same(result[1], {
      kind = 1,
      label = ": string",
      paddingLeft = true,
      paddingRight = false,
      position = {
        character = 15,
        line = 0,
      },
    })
    assert.is.same(result[2], {
      label = "= 0",
      paddingLeft = true,
      paddingRight = false,
      position = {
        character = 5,
        line = 5,
      },
    })
    assert.is.same(result[3], {
      kind = 1,
      label = ": string",
      paddingLeft = true,
      paddingRight = false,
      position = {
        character = 7,
        line = 8,
      },
    })
  end)

  it("should return correct response for " .. methods.CodeLens, function()
    utils.open_file "src/diagnostic1.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.CodeLens, {
      textDocument = utils.get_text_document(),
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result)

    local file_uri = "file://" .. vim.fn.getcwd() .. "/src/diagnostic1.ts"
    ---@diagnostic disable-next-line
    assert.is.same(result[1].data.textDocument.uri, file_uri)
  end)

  it("should return correct response for " .. methods.CodeLensResolve, function()
    utils.open_file "src/diagnostic1.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, methods.CodeLensResolve, {
      data = {
        textDocument = utils.get_text_document(),
      },
      range = {
        start = { character = 13, line = 0 },
      },
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result)
    assert.is.table(result.command)

    local version = v.parse(vim.env.TEST_TYPESCRIPT_VERSION)

    if version and v.lt(version, { 4, 5 }) then
      assert.is.same(result.command.title, "references: 1")
    else
      assert.is.same(result.command.title, "references: 2")
    end
  end)

  it("should return correct response for " .. custom_methods.JsxClosingTag, function()
    utils.open_file "src/jsx_close_tag.tsx"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, custom_methods.JsxClosingTag, {
      position = utils.make_position(0, 5),
      textDocument = utils.get_text_document(),
    })

    local result = lsp_assert.response(ret)

    assert.is.table(result)

    assert.is.same(result, {
      newText = "</div>",
      caretOffset = 0,
    })
  end)

  it("should return correct response for " .. custom_methods.FileReferences, function()
    local version = v.parse(vim.env.TEST_TYPESCRIPT_VERSION)
    if version and v.lt(version, { 4, 2 }) then
      utils.print_skip "`fileReferences` request isn't supported in typescript version below 4.2"
      return
    end

    utils.open_file "src/exports.ts"
    utils.wait_for_lsp_initialization()

    local ret = vim.lsp.buf_request_sync(0, custom_methods.FileReferences, {
      textDocument = utils.get_text_document(),
    })

    local result = lsp_assert.response(ret)
    assert.are.same(#result, 1)
    assert.are.same(result[1].uri, "file://" .. vim.fn.getcwd() .. "/src/imports.ts")
  end)
end)
