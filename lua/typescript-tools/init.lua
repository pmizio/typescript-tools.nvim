local lspconfig = require "lspconfig"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"
local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"

local M = {}

function M.setup(config)
  local settings = config.settings or {}

  plugin_config.load_settings(settings)

  if configs[plugin_config.plugin_name] == nil then
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
        root_dir = function(fname)
          -- INFO: stealed from:
          -- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/tsserver.lua#L22
          local root_dir = util.root_pattern "tsconfig.json"(fname)
            or util.root_pattern("package.json", "jsconfig.json", ".git")(fname)

          -- INFO: this is needed to make sure we don't pick up root_dir inside node_modules
          local node_modules_index = root_dir and root_dir:find("node_modules", 1, true)
          if node_modules_index and node_modules_index > 0 then
            root_dir = root_dir:sub(1, node_modules_index - 2)
          end

          return root_dir
        end,
        single_file_support = true,
      },
    }
  end

  lspconfig[plugin_config.plugin_name].setup(config)
end

return M
