# typescript-tools.nvim

## TODO: description

```lua
 NeoVim                                                    Tsserver Magic
┌────────────────────────────────────────────┐            ┌────────────────┐
│                                            │            │                │
│  LSP Loop              Tsserver Loop       │            │                │
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

| Status | Request                         |
| ------ | ------------------------------- |
| ✅     | textDocument/completion         |
| ✅     | textDocument/hover              |
| ✅     | textDocument/rename             |
| ✅     | textDocument/publishDiagnostics |
| ✅     | textDocument/signatureHelp      |
| ✅     | textDocument/references         |
| ✅     | textDocument/definition         |
| ✅     | textDocument/typeDefinition     |
| ✅     | textDocument/implementation     |
| ✅     | textDocument/documentSymbol     |
| ✅     | textDocument/documentHighlight  |
| ✅     | textDocument/codeAction         |
| ✅     | textDocument/formatting         |
| ✅     | textDocument/rangeFormatting    |
| ✅     | callHierarchy/incomingCalls     |
| ✅     | callHierarchy/outgoingCalls     |
| ✅     | workspace/symbol                |
| ❌     | workspace/applyEdit - N/A       |
| ❌     | textDocument/declaration - N/A  |
| ❌     | window/logMessage - N/A         |
| ❌     | window/showMessage - N/A        |
| ❌     | window/showMessageRequest - N/A |

## Development

Useful links:

- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Run tests

Running tests requires [plenary.nvim][plenary] to be checked out in the parent directory of _this_ repository.
You can then run:

```bash
make test
```

Or if you want to run a single test file:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/path_to_file.lua {minimal_init = 'tests/minimal.vim'}"
```
