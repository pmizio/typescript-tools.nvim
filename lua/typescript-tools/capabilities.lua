local lspProtocol = require "vim.lsp.protocol"
local constants = require "typescript-tools.protocol.constants"

local function make_capabilities(settings)
  return {
    textDocumentSync = lspProtocol.TextDocumentSyncKind.Incremental,
    renameProvider = {
      -- tsserver doesn't have something like textDocument/prepareRename
      prepareProvider = false,
    },
    completionProvider = {
      resolveProvider = true,
      triggerCharacters = {
        ".",
        '"',
        "'",
        "`",
        "/",
        "@",
        "<",
      },
    },
    hoverProvider = true,
    definitionProvider = true,
    typeDefinitionProvider = true,
    foldingRangeProvider = true,
    semanticTokensProvider = {
      documentSelector = nil,
      legend = {
        -- list taken from: https://github.com/microsoft/TypeScript/blob/main/src/services/classifier2020.ts#L10
        tokenTypes = {
          "class",
          "enum",
          "interface",
          "namespace",
          "typeParameter",
          "type",
          "parameter",
          "variable",
          "enumMember",
          "property",
          "function",
          "member",
        },
        -- token from: https://github.com/microsoft/TypeScript/blob/main/src/services/classifier2020.ts#L14
        tokenModifiers = {
          "declaration",
          "static",
          "async",
          "readonly",
          "defaultLibrary",
          "local",
        },
      },
      full = true,
    },
    declarationProvider = false,
    implementationProvider = true,
    referencesProvider = true,
    documentSymbolProvider = true,
    documentHighlightProvider = true,
    signatureHelpProvider = {
      triggerCharacters = { "(", ",", "<" },
      retriggerCharacters = { ")" },
    },
    codeActionProvider = {
      codeActionKinds = {
        constants.CodeActionKind.Empty,
        constants.CodeActionKind.QuickFix,
        constants.CodeActionKind.Refactor,
        constants.CodeActionKind.RefactorExtract,
        constants.CodeActionKind.RefactorInline,
        constants.CodeActionKind.RefactorRewrite,
        constants.CodeActionKind.Source,
        constants.CodeActionKind.SourceOrganizeImports,
      },
      resolveProvider = true,
    },
    workspace = {
      fileOperations = {
        willRename = {
          filters = {
            {
              scheme = "file",
              pattern = { glob = "**/*.{ts,js,jsx,tsx,mjs,mts,cjs,cts}", matches = "file" },
            },
            {
              scheme = "file",
              pattern = { glob = "**/*", matches = "folder" },
            },
          },
        },
      },
    },
    documentFormattingProvider = settings.enable_formatting,
    documentRangeFormattingProvider = settings.enable_formatting,
    callHierarchyProvider = true,
    workspaceSymbolProvider = true,
  }
end

return make_capabilities
