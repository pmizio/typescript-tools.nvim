local lsp_protocol = require "vim.lsp.protocol"
local TsserverProvider = require "typescript-tools.tsserver_provider"
local utils = require "typescript-tools.utils"
local c = require "typescript-tools.protocol.constants"
local config = require "typescript-tools.config"

local function make_capabilities()
  local tsserver_provider = TsserverProvider.get_instance()
  local version = tsserver_provider:get_version()

  return {
    textDocumentSync = lsp_protocol.TextDocumentSyncKind.Incremental,
    executeCommandProvider = {
      commands = {
        c.InternalCommands.InvokeAdditionalRename,
        c.InternalCommands.CallApiFunction,
        c.InternalCommands.RequestReferences,
        c.InternalCommands.RequestImplementations,
      },
    },
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
    inlayHintProvider = not utils.version_compare("lt", version, { 4, 4 }),
    foldingRangeProvider = true,
    semanticTokensProvider = not utils.version_compare("lt", version, { 4, 1 })
        and {
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
        }
      or false,
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
    codeLensProvider = config.code_lens ~= config.code_lens_mode.off and vim.treesitter and {
      resolveProvider = true,
    },
  }
end

return make_capabilities
