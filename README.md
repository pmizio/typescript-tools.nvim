<h1 align="center">typescript-tools.nvim</h1>
<p align="center"><sup>⚡ TypeScript integration NeoVim deserves ⚡</sup></p>

### 🚧 Warning 🚧

Please note that the plugin is currently in the early beta version, which means you may encounter bugs.

### ⁉️ Why?

1. Drop in, pure lua replacement for `typescript-language-server`
2. If you work on a large TS/JS project, you probably understand why this plugin came into existence.
   The `typescript-language-server` can be extremely slow in such projects,
   and it often fails to provide accurate completions or just crash.

### ✨ Features

- ⚡ Blazing fast, thanks to the utilization of the native Tsserver communication protocol, similar to Visual Studio Code
- 🪭 Supports a wide range of TypeScript versions 4.0 and above
- 🌍 Supports the nvim LSP plugin ecosystem
- 🔀 Supports multiple instances of Tsserver
- 💻 Supports both local and global installations of TypeScript
- 💅 Provides out-of-the-box support for styled-components, which is not enabled by default (see Installation and [Configuration](#-styled-components-support))
- ✨ Improved code refactor capabilities e.g. extracting to variable or function

### 🚀 How it works?

<details>
  <summary>If you're interested in learning more about the technical details of the plugin, you can click here.</summary>
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

</details>

### 📦 Installation

> ❗️ IMPORTANT: As mentioned earlier, this plugin serves as a replacement for `typescript-language-server`,
> so you should remove the `nvim-lspconfig` setup for it.

#### ⚡️ Requirements

- NeoVim >= 0.8.0
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- TypeScript >= 4.0
- Node supported suitable for TypeScript version you use

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
  on_attach = function() ... end,
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
instance. You can find available options in `typescript` repository (e.g.
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

| Status | Request                 |
| ------ | ----------------------- |
| ✅     | textDocument/completion |
| ✅     | textDocument/hover      |
| ✅     | textDocument/rename     |
