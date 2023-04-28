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
