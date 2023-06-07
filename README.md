# typescript-tools.nvim

## TODO: description

```lua
 NeoVim                                                    Tsserver Instance
┌────────────────────────────────────────────┐            ┌────────────────┐
│                                            │            │                │
│  LSP Handlers          Tsserver LSP Loop   │            │                │
│ ┌─────────┐           ┌──────────────────┐ │            │                │
│ │         │           │                  │ │            │                │
│ │         │ Request   │ ┌──────────────┐ │ │            │                │
│ │         ├───────────┤►│ Translation  │ │ │            │                │
│ │         │ Response  │ │    Layer     │ │ │            │                │
│ │         ◄───────────┼─┤              │ │ │            │                │
│ │         │           │ └───┬─────▲────┘ │ │            │                │
│ │         │           │     │     │      │ │            │                │
│ │         │           │ ┌───▼─────┴────┐ │ │ Request    │                │
│ │         │           │ │   I/O Loop   ├─┼─┼────────────►                │
│ │         │           │ │              │ │ │ Response   │                │
│ │         │           │ │              ◄─┼─┼────────────┤                │
│ │         │           │ └──────────────┘ │ │            │                │
│ │         │           │                  │ │            │                │
│ └─────────┘           └──────────────────┘ │            │                │
│                                            │            │                │
└────────────────────────────────────────────┘            └────────────────┘
```

## Supported lsp methods

| Status | Request                                                   |
| ------ | ----------------------------------------------------------|
| ✅     | textDocument/completion                                   |
| ✅     | textDocument/hover                                        |
| ✅     | textDocument/rename                                       |
| ✅     | textDocument/publishDiagnostics                           |
| ✅     | textDocument/signatureHelp                                |
| ✅     | textDocument/references                                   |
| ✅     | textDocument/definition                                   |
| ✅     | textDocument/typeDefinition                               |
| ✅     | textDocument/implementation                               |
| ✅     | textDocument/documentSymbol                               |
| ✅     | textDocument/documentHighlight                            |
| ✅     | textDocument/codeAction                                   |
| ✅     | textDocument/formatting                                   |
| ✅     | textDocument/rangeFormatting                              |
| ✅     | textDocument/foldingRange                                 |
| ✅     | textDocument/semanticTokens/full (supported from TS v4.1) |
| ✅     | textDocument/inlayHint (supported from TS v4.4)           |
| ✅     | callHierarchy/incomingCalls                               |
| ✅     | callHierarchy/outgoingCalls                               |
| ✅     | workspace/symbol                                          |
| ✅     | workspace/willRenameFiles                                 |
| ❌     | workspace/applyEdit - N/A                                 |
| ❌     | textDocument/declaration - N/A                            |
| ❌     | window/logMessage - N/A                                   |
| ❌     | window/showMessage - N/A                                  |
| ❌     | window/showMessageRequest - N/A                           |

### Configuration
You can pass custom configuration options that will be passed to `tsserver` instance. You can find 
available options in `typescript` repositorory (e.g. for version 5.0.4 of typescript):
- [tsserver_file_preferences](https://github.com/microsoft/TypeScript/blob/v5.0.4/src/server/protocol.ts#L3439)
- [tsserver_format_options](https://github.com/microsoft/TypeScript/blob/v5.0.4/src/server/protocol.ts#L3418)

To pass those options to plugin pass them to the plugin `setup` function:

```lua
typescript_tools.setup({
  settings = {
    ...
    tsserver_file_preferences = {
      includeInlayParameterNameHints = "all",
      includeCompletionsForModuleExports = true,
      quotePreference = "auto",
      ...
    },
    tsserver_format_options = {
      allowIncompleteCompletions = false,
      allowRenameOfImportPath = false,
      ...
    }
  },
})
```

The default values for `preferences` and `format_options` are in [this file](https://github.com/pmizio/typescript-tools.nvim/blob/master/lua/typescript-tools/protocol/text_document/did_open.lua#L8)

## Development

Useful links:

- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Run tests

Running tests requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to be checked out in the parent directory of _this_ repository.
Make sure you have [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) plugin.
You can then run:

```bash
make test
```

Or if you want to run a single test file:

```bash
make file=test_spec.lua test
```
