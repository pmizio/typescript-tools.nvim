local lspProtocol = require "vim.lsp.protocol"
local c = require "typescript-tools.protocol.constants"

local capabilities = {
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
      c.CodeActionKind.Empty,
      c.CodeActionKind.QuickFix,
      c.CodeActionKind.Refactor,
      c.CodeActionKind.RefactorExtract,
      c.CodeActionKind.RefactorInline,
      c.CodeActionKind.RefactorRewrite,
      c.CodeActionKind.Source,
      c.CodeActionKind.SourceOrganizeImports,
    },
    resolveProvider = true,
  },
  inlayHintProvider = true,
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
  documentFormattingProvider = true,
  documentRangeFormattingProvider = true,
  callHierarchyProvider = true,
  workspaceSymbolProvider = true,
}

return capabilities
