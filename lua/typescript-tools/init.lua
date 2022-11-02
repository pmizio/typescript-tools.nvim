local log = require "vim.lsp.log"
local lspconfig = require "lspconfig"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"
local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"

local M = {}

M.setup = function(config)
  local settings = config.settings or {}

  plugin_config.load_and_validate(settings)

  configs[plugin_config.NAME] = {
    default_config = {
      cmd = function(...)
        local ok, tsserver_rpc = pcall(rpc.start, plugin_config.NAME, ...)
        if ok then
          return tsserver_rpc
        else
          log.error(tsserver_rpc)
        end

        return nil
      end,
      filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
      },
      -- stealed from:
      -- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/tsserver.lua#L22
      root_dir = function(fname)
        return util.root_pattern "tsconfig.json"(fname)
          or util.root_pattern("package.json", "jsconfig.json", ".git")(fname)
      end,
    },
  }

  lspconfig[plugin_config.NAME].setup(config)
end

return M
