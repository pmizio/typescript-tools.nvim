<h1 align="center">typescript-tools.nvim</h1>
<p align="center"><sup>⚡ TypeScript integration NeoVim deserves ⚡</sup></p>

### 🚧 Warning 🚧

Please note that the plugin is currently in the early beta version, which means you may encounter
bugs.

### ⁉️ Why?

1. Drop in, pure lua replacement for `typescript-language-server`
2. If you work on a large TS/JS project, you probably understand why this plugin came into existence.
   The `typescript-language-server` can be extremely slow in such projects,
   and it often fails to provide accurate completions or just crash.

### ✨ Features

- ⚡ Blazingly fast, thanks to the utilization of the native Tsserver communication protocol,
  similar to Visual Studio Code
- 🪭 Supports a wide range of TypeScript versions 4.0 and above
- 🌍 Supports the nvim LSP plugin ecosystem
- 🔀 Supports multiple instances of Tsserver
- 💻 Supports both local and global installations of TypeScript
- 🔨 Supports `tsserver` installed from [Mason](https://github.com/williamboman/mason.nvim)
- 💅 Provides out-of-the-box support for styled-components, which is not enabled by default
  (see Installation and [Configuration](#-styled-components-support))
- ✨ Improved code refactor capabilities e.g. extracting to variable or function

![code_action](https://github.com/pmizio/typescript-tools.nvim/assets/4346598/50f87c54-c286-473d-ba3d-886ac97ca072)

### 🚀 How it works?

<details>
  <summary>
    If you're interested in learning more about the technical details of the plugin, you can click here.
  </summary>
  <p>
    <br>
    This plugin functions exactly like the bundled TypeScript support extension in Visual Studio Code.
    Thanks to the new (0.8.0) NeoVim API, it is now possible to pass a Lua function as the LSP start
    command. As a result, the plugin spawns a custom version of the I/O loop to communicate directly
    with Tsserver using its native protocol, without the need for any additional proxy.
    The Tsserver protocol, which is a JSON-based communication protocol, likely served as inspiration
    for the LSP. However, it is incompatible with the LSP. To address this, the I/O loop provided by
    this plugin features a translation layer that converts all messages to and from the Tsserver format.
  </p>

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
{
  "pmizio/typescript-tools.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  opts = {},
}
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "pmizio/typescript-tools.nvim",
  requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  config = function()
    require("typescript-tools").setup {}
  end,
}
```

### ⚙️ Configuration

The parameters passed into the `setup` function are also passed to the standard `nvim-lspconfig`
server `setup`, allowing you to use the same settings here.
But you can pass plugin-specific options through the `settings` parameter, which defaults to:

```lua
require("typescript-tools").setup {
  on_attach = function() ... end,
  handlers = { ... },
  ...
  settings = {
    -- spawn additional tsserver instance to calculate diagnostics on it
    separate_diagnostic_server = true,
    -- "change"|"insert_leave" determine when the client asks the server about diagnostic
    publish_diagnostic_on = "insert_leave",
    -- array of strings("fix_all"|"add_missing_imports"|"remove_unused"|
    -- "remove_unused_imports"|"organize_imports") -- or string "all"
    -- to include all supported code actions
    -- specify commands exposed as code_actions
    expose_as_code_action = {},
    -- string|nil - specify a custom path to `tsserver.js` file, if this is nil or file under path
    -- not exists then standard path resolution strategy is applied
    tsserver_path = nil,
    -- specify a list of plugins to load by tsserver, e.g., for support `styled-components`
    -- (see 💅 `styled-components` support section)
    tsserver_plugins = {},
    -- this value is passed to: https://nodejs.org/api/cli.html#--max-old-space-sizesize-in-megabytes
    -- memory limit in megabytes or "auto"(basically no limit)
    tsserver_max_memory = "auto",
    -- described below
    tsserver_format_options = {},
    tsserver_file_preferences = {},
    -- locale of all tsserver messages, supported locales you can find here:
    -- https://github.com/microsoft/TypeScript/blob/3c221fc086be52b19801f6e8d82596d04607ede6/src/compiler/utilitiesPublic.ts#L620
    tsserver_locale = "en",
    -- mirror of VSCode's `typescript.suggest.completeFunctionCalls`
    complete_function_calls = false,
    include_completions_with_insert_text = true,
    -- CodeLens
    -- WARNING: Experimental feature also in VSCode, because it might hit performance of server.
    -- possible values: ("off"|"all"|"implementations_only"|"references_only")
    code_lens = "off",
    -- by default code lenses are displayed on all referencable values and for some of you it can
    -- be too much this option reduce count of them by removing member references from lenses
    disable_member_code_lens = true,
    -- JSXCloseTag
    -- WARNING: it is disabled by default (maybe you configuration or distro already uses nvim-ts-autotag,
    -- that maybe have a conflict if enable this feature. )
    jsx_close_tag = {
        enable = false,
        filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}
```

Note that `handlers` can be used to override certain LSP methods.
For example, you can use the `filter_diagnostics` helper to ignore specific errors:

```lua
local api = require("typescript-tools.api")
require("typescript-tools").setup {
  handlers = {
    ["textDocument/publishDiagnostics"] = api.filter_diagnostics(
      -- Ignore 'This may be converted to an async function' diagnostics.
      { 80006 }
    ),
  },
}
```

You can also pass custom configuration options that will be passed to `tsserver`
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

If you want to make `tsserver_format_options` or `tsserver_file_preferences` filetype dependant you
need to may set them as functions returning tables eg.

<details>
  <summary>Example code here</summary>
  <p>

```lua
require("typescript-tools").setup {
  settings = {
    ...
    tsserver_file_preferences = function(ft)
      -- Some "ifology" using `ft` of opened file
      return {
        includeInlayParameterNameHints = "all",
        includeCompletionsForModuleExports = true,
        quotePreference = "auto",
        ...
      }
    end,
    tsserver_format_options = function(ft)
      -- Some "ifology" using `ft` of opened file
      return {
        allowIncompleteCompletions = false,
        allowRenameOfImportPath = false,
        ...
      }
    end
  },
}
```

  </p>
</details>

The default values for `preferences` and `format_options` are in [this file](https://github.com/pmizio/typescript-tools.nvim/blob/master/lua/typescript-tools/config.lua#L17)

#### 💅 `styled-components` support

<details>
  <summary>Show more</summary>
  <p>
    <br>
    To get IntelliSense for <code>styled-components</code>, you need to install the tsserver plugin
    globally, which enables support for it:
  </p>

```
npm i -g @styled/typescript-styled-plugin typescript-styled-plugin
```

Now, you need to load the plugin by modifying the `settings` object as follows:

```lua
require("typescript-tools").setup {
  settings = {
    ...
    tsserver_plugins = {
      -- for TypeScript v4.9+
      "@styled/typescript-styled-plugin",
      -- or for older TypeScript versions
      -- "typescript-styled-plugin",
    },
  },
}
```

</details>

## Custom user commands

This plugin provides several custom user commands (they are only applied to current buffer):

- `TSToolsOrganizeImports` - sorts and removes unused imports
- `TSToolsSortImports` - sorts imports
- `TSToolsRemoveUnusedImports` - removes unused imports
- `TSToolsRemoveUnused` - removes all unused statements
- `TSToolsAddMissingImports` - adds imports for all statements that lack one and can be imported
- `TSToolsFixAll` - fixes all fixable errors
- `TSToolsGoToSourceDefinition` - goes to
  [source definition](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-7.html#go-to-source-definition)
  (available since TS v4.7)
- `TSToolsRenameFile` - allow to rename current file and apply changes to connected files
- `TSToolsFileReferences` - find files that reference the current file (available since TS v4.2)

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
| ✅     | textDocument/codeLens                                     |
| 🚧     | textDocument/linkedEditingRange (planned)                 |
| ✅     | workspace/symbol                                          |
| ✅     | workspace/willRenameFiles                                 |
| ❌     | workspace/applyEdit - N/A                                 |
| ❌     | textDocument/declaration - N/A                            |
| ❌     | window/logMessage - N/A                                   |
| ❌     | window/showMessage - N/A                                  |
| ❌     | window/showMessageRequest - N/A                           |

## 🚦 Roadmap

- `textDocument/linkedEditingRange` - [#32](https://github.com/pmizio/typescript-tools.nvim/pull/32)
- Embedded language support(JS inside of HTML) - [#43](https://github.com/pmizio/typescript-tools.nvim/pull/43)

## 🔨 Development

Useful links:

- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### 🐛 Run tests

The unit testing environment is automatically bootstrapped, just run:

```
make test
```

Or if you want to run a single test file:

```
make file=test_spec.lua test
```

## 💐 Credits

- [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim)
  \- for the idea to monkeypatch nvim API to start a custom LSP I/O loop
- [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server)
  \- for ideas on how to translate certain Tsserver responses
- [Visual Studio Code(TypeScript extension)](https://github.com/microsoft/vscode/tree/main/extensions/typescript-language-features)
  \- for insights on using the Tsserver protocol and performance optimizations
