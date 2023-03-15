<h1 align="center">typescript-tools.nvim</h1>
<p align="center"><sup>Typescript integration NeoVim deserves ⚡</sup></p>

### 🚧 Warning 🚧

Plugin is in early stages of development so you can encounter bugs.

### Why?

If you work on huge TS/JS project you exactly know why this plugin come into existance -
typescript-language-server can be very, very slow in this type of projects.
Beside slowness it also often miss completions or just simply crash.

### Features

- Support wide set of Typescript versions 4.0+
- Support nvim LSP plugin ecosystem
- Use native Tsserver communication protocol(just like VisualStudio Code)
- Support mutliple instances of Tsserver
- Support local and global installation of Typescript
- Out of the box styled-components support, but not enabled by default(see Installation and Configuration)

### How it works?

This plugin works exactly like bundled VisualStudio Code Typescript support extension. Thanks to
new(0.8.0) NeoVim API which allow to pass lua function as LSP start command, plugin spawn
custom version of I/O loop to communicate with Tsserver over its native protocol without any
additional proxy. Tsserver protocol is also json based communication protocol and it is probably
inspiration for LSP but sadly it is incompatible with LSP, to address this I/O loop provided
by this plugin feature translation layer to convert all messages from or to Tsserver shape.
Long story short below graph show how architecture of this plugin look like:

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

### Requirements

- NeoVim >= 0.8.0
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Typescript >= 4.0
- Node supported suitable for Typescript version you use

### Installation

TODO

### Configuration

TODO

### Supported LSP methods

Below table show current status of supported LSP methods.

| Status | Request                         | Note                                                           |
| ------ | ------------------------------- | -------------------------------------------------------------- |
| ✅     | textDocument/completion         |                                                                |
| ✅     | textDocument/hover              |                                                                |
| ✅     | textDocument/rename             |                                                                |
| ✅     | textDocument/publishDiagnostics |                                                                |
| ✅     | textDocument/signatureHelp      |                                                                |
| ✅     | textDocument/references         |                                                                |
| ✅     | textDocument/definition         |                                                                |
| ✅     | textDocument/typeDefinition     |                                                                |
| ✅     | textDocument/implementation     |                                                                |
| ✅     | textDocument/documentSymbol     |                                                                |
| ✅     | textDocument/documentHighlight  |                                                                |
| ✅     | textDocument/codeAction         |                                                                |
| ✅     | textDocument/formatting         |                                                                |
| ✅     | textDocument/rangeFormatting    |                                                                |
| 🚧     | textDocument/semanticTokens/\*  |                                                                |
| 🚧     | inlayHint/resolve               | Wait for [#20130](https://github.com/neovim/neovim/pull/20130) |
| ✅     | callHierarchy/incomingCalls     |                                                                |
| ✅     | callHierarchy/outgoingCalls     |                                                                |
| ✅     | workspace/symbol                |                                                                |
| ✅     | workspace/willRenameFiles       |                                                                |
| ❌     | workspace/applyEdit - N/A       |                                                                |
| ❌     | textDocument/declaration - N/A  |                                                                |
| ❌     | window/logMessage - N/A         |                                                                |
| ❌     | window/showMessage - N/A        |                                                                |
| ❌     | window/showMessageRequest - N/A |                                                                |

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
