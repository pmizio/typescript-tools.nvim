local lspconfig = require "lspconfig"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"
local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"
local user_commands = require "typescript-tools.user_commands"

local M = {}

M.setup = function(config)
  local settings = config.settings or {}

  plugin_config.load_and_validate(settings)

  configs[plugin_config.NAME] = vim.tbl_extend("force", {
    default_config = {
      cmd = function(...)
        return rpc.start(plugin_config.NAME, ...)
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
  }, config)

  lspconfig[plugin_config.NAME].setup(config)
  user_commands.setup_user_commands()
end

return M
