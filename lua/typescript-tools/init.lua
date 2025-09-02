local util = require "typescript-tools.utils"
local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"

local M = {}

function M.setup(config)
  local version_ok, version_msg = util.check_minimum_nvim_version()
  if not version_ok then
    vim.notify(string.format("[typescript-tools.nvim] %s", version_msg), vim.log.levels.ERROR)
    return
  end
  local settings = config.settings or {}

  plugin_config.load_settings(settings)

  if vim.lsp.config[plugin_config.plugin_name] == nil then
    vim.lsp.config[plugin_config.plugin_name] = {
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
      root_dir = function(bufnr, on_dir)
        on_dir(util.get_root_dir(bufnr))
      end,
      single_file_support = true,
    }
  end

  vim.lsp.enable(plugin_config.plugin_name)
end

return M
