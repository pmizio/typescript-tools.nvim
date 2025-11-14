local util = require "typescript-tools.utils"
local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"

local M = {}

---@param config { settings?: table, config?: vim.lsp.Config }
function M.setup(config)
  config = config or {}

  local version_ok, version_msg = util.check_minimum_nvim_version()
  if not version_ok then
    vim.notify(string.format("[typescript-tools.nvim] %s", version_msg), vim.log.levels.ERROR)
    return
  end
  local settings = config.settings or {}

  plugin_config.load_settings(settings)

  -- Extract LSP config options (on_attach, capabilities, etc.)
  -- Filter out plugin-specific options like 'settings'
  local lsp_config = {}
  for key, value in pairs(config) do
    if key ~= "settings" then
      lsp_config[key] = value
    end
  end

  if vim.lsp.config[plugin_config.plugin_name] == nil then
    vim.lsp.config[plugin_config.plugin_name] = vim.tbl_deep_extend("keep", lsp_config, {
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
    })
  end

  vim.lsp.enable(plugin_config.plugin_name)
end

return M
