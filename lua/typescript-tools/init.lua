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

  -- INFO: some nasty ifology but it need to be placed somewhere
  -- I prefer it here than in huge file tsserver.lua
  -- Rationale: `on_attach` is called based on response from `configure` request and because we
  -- have two servers nvim get also two responses
  local on_attach_called = false
  local config_on_attach = config.on_attach

  local function on_attach(...)
    if on_attach_called then
      return
    end

    on_attach_called = true
    config_on_attach(...)
  end

  if config.on_attach then
    config.on_attach = on_attach
  end

  lspconfig[plugin_config.plugin_name].setup(config)
end

return M
