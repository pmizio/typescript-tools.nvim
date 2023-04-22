local lspconfig = require "lspconfig"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"
local rpc = require "typescript-tools.new.rpc"
local plugin_config = require "typescript-tools.new.config"

local M = {}

M.setup = function(config)
  local settings = config.settings or {}

  plugin_config.load_settings(settings)

  configs[plugin_config.plugin_name] = {
    default_config = {
      cmd = function(...)
        return rpc.start(...)
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

  lspconfig[plugin_config.plugin_name].setup(config)
end

return M
