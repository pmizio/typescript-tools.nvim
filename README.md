<h1 align="center">typescript-tools.nvim</h1>
<p align="center"><sup>Typescript integration NeoVim deserves ⚡</sup></p>

### 🚧 Warning 🚧

The plugin is in the early stages of development, so you may encounter bugs.

### ⁉️ Why?

If you work on huge TS/JS project you exactly know why this plugin come into existance -
typescript-language-server can be very, very slow in this type of projects.
Beside slowness it also often miss completions or just simply crash.

If you work on a large TS/JS project, you probably understand why this plugin came into existence.
The typescript-language-server can be extremely slow in such projects,
and it often fails to provide accurate completions or just crash.

### ✨ Features

- Supports a wide range of TypeScript versions 4.0 and above
- Supports the nvim LSP plugin ecosystem
- Utilizes the native Tsserver communication protocol, similar to Visual Studio Code
- Supports multiple instances of Tsserver
- Supports both local and global installations of TypeScript
- Provides out-of-the-box support for styled-components, which is not enabled by default (see Installation and Configuration)

### 🚀 How it works?

This plugin functions exactly like the bundled TypeScript support extension in Visual Studio Code.
Thanks to the new (0.8.0) NeoVim API, it is now possible to pass a Lua function as the LSP start command.
As a result, the plugin spawns a custom version of the I/O loop to communicate directly with Tsserver
using its native protocol, without the need for any additional proxy.
The Tsserver protocol, which is a JSON-based communication protocol, likely served as inspiration for the LSP.
However, it is incompatible with the LSP. To address this, the I/O loop provided by this plugin features a
translation layer that converts all messages to and from the Tsserver format.

In summary, the architecture of this plugin can be visualized as shown in the diagram below:

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

### ⚡️ Requirements

- NeoVim >= 0.8.0
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- TypeScript >= 4.0
- Node supported suitable for TypeScript version you use

### 📦 Installation

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "pmizio/typescript-tools.nvim", opts = {} }
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "pmizio/typescript-tools.nvim"
  config = function()
    require("typescript-tools").setup {}
  end,
}
```

### ⚙️ Configuration

The parameters passed into the `setup` function are also passed to the standard `nvim-lspconfig` server `setup`,
allowing you to use the same settings here.
But you can pass plugin-specific options through the `settings` parameter, which defaults to:

```lua
require("typescript-tools").setup {
  ...
  settings = {
    -- spawn additional tsserver instance to calculate diagnostics on it
    separate_diagnostic_server = true,
    -- "change"|"insert_leave" determine when the client asks the server about diagnostic
    publish_diagnostic_on = "insert_leave",
    -- specify a list of plugins to load by tsserver, e.g., for support `styled-components`(see 💅 `styled-components` support section)
    tsserver_plugins = {},
    -- described below
    tsserver_format_options = {},
    tsserver_file_preferences = {},
  },
}
```

You can pass custom configuration options that will be passed to `tsserver`
instance. You can find available options in `typescript` repositorory (e.g.
for version 5.0.4 of typescript):

- [tsserver_file_preferences](https://github.com/microsoft/TypeScript/blob/v5.0.4/src/server/protocol.ts#L3439)
- [tsserver_format_options](https://github.com/microsoft/TypeScript/blob/v5.0.4/src/server/protocol.ts#L3418)

To pass those options to plugin pass them to the plugin `setup` function:

```lua
require("typescript-tools").setup {
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
}
```

The default values for `preferences` and `format_options` are in [this file](https://github.com/pmizio/typescript-tools.nvim/blob/master/lua/typescript-tools/protocol/text_document/did_open.lua#L8)

#### 💅 `styled-components` support

<details>
  <summary>Show more</summary>
To get IntelliSense for `styled-components`, you need to install the tsserver plugin globally, which enables support for it:

```bash
npm i -g typescript-styled-plugin
```

Now, you need to load the plugin by modifying the `settings` object as follows:

```lua
require("typescript-tools").setup {
  settings = {
    ...
    tsserver_plugins = { "typescript-styled-plugin" },
  },
}
```

</details>

## Supported LSP methods

| Status | Request                                                   |
| ------ | --------------------------------------------------------- |
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
| 🚧     | textDocument/codeLens(#39)                                |
| 🚧     | textDocument/linkedEditingRange (planned)                 |
| ✅     | workspace/symbol                                          |
| ✅     | workspace/willRenameFiles                                 |
| ❌     | workspace/applyEdit - N/A                                 |
| ❌     | textDocument/declaration - N/A                            |
| ❌     | window/logMessage - N/A                                   |
| ❌     | window/showMessage - N/A                                  |
| ❌     | window/showMessageRequest - N/A                           |

## 🔨 Development

Useful links:

- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### 🐛 Run tests

Running tests requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
to be checked out in the parent directory of _this_ repository.
Make sure you have [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) plugin.
You can then run:

```bash
make test
```

Or if you want to run a single test file:

```bash
make file=test_spec.lua test
```
