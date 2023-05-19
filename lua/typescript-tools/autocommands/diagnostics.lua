local api = vim.api

local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"
local plugin_api = require "typescript-tools.api"
local proto_utils = require "typescript-tools.protocol.utils"

local publish_diagnostic_mode = plugin_config.publish_diagnostic_mode

local extensions_pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" }

local M = {}

local function request_diagnostics_api_wrapper()
  plugin_api.request_diagnostics()
end

local request_diagnostics_throttled = utils.throttle(200, request_diagnostics_api_wrapper)
local request_diagnostics_debounced = utils.debounce(200, request_diagnostics_api_wrapper)

---@param augroup number
---@param dispatchers Dispatchers
function M.setup_diagnostic_autocmds(augroup, dispatchers)
  if plugin_config.publish_diagnostic_on == publish_diagnostic_mode.change then
    api.nvim_create_autocmd("User", {
      pattern = {
        "TypescriptTools_" .. c.LspMethods.DidOpen,
        "TypescriptTools_" .. c.LspMethods.DidChange,
      },
      callback = request_diagnostics_throttled,
      group = augroup,
    })
  end

  if plugin_config.publish_diagnostic_on == publish_diagnostic_mode.insert_leave then
    api.nvim_create_autocmd("InsertEnter", {
      pattern = extensions_pattern,
      callback = function()
        proto_utils.publish_diagnostics(dispatchers, vim.uri_from_bufnr(0), {})
      end,
      group = augroup,
    })

    api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
      pattern = extensions_pattern,
      callback = request_diagnostics_debounced,
      group = augroup,
    })
  end
end

return M
