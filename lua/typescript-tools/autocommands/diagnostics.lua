local api = vim.api

local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"
local plugin_api = require "typescript-tools.api"

local publish_diagnostic_mode = plugin_config.publish_diagnostic_mode

local M = {}

local function request_diagnostics_api_wrapper()
  plugin_api.request_diagnostics()
end

local request_diagnostics_throttled = utils.throttle(200, request_diagnostics_api_wrapper)
local request_diagnostics_debounced = utils.debounce(200, request_diagnostics_api_wrapper)

---@param augroup number
function M.setup_diagnostic_autocmds(augroup)
  local pattern = { "TypescriptTools_" .. c.LspMethods.DidOpen }

  if plugin_config.publish_diagnostic_on == publish_diagnostic_mode.change then
    table.insert(pattern, "TypescriptTools_" .. c.LspMethods.DidChange)
  end

  api.nvim_create_autocmd("User", {
    pattern = pattern,
    callback = request_diagnostics_throttled,
    group = augroup,
  })

  if plugin_config.publish_diagnostic_on == publish_diagnostic_mode.insert_leave then
    api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
      pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" },
      callback = request_diagnostics_debounced,
      group = augroup,
    })
  end
end

return M
