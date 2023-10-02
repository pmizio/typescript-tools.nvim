local api = vim.api

local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"
local plugin_api = require "typescript-tools.api"
local proto_utils = require "typescript-tools.protocol.utils"
local common = require "typescript-tools.autocommands.common"

local publish_diagnostic_mode = plugin_config.publish_diagnostic_mode

local M = {}

local function request_diagnostics_api_wrapper()
  plugin_api.request_diagnostics()
end

local request_diagnostics_throttled = utils.throttle(200, request_diagnostics_api_wrapper)
local request_diagnostics_debounced = utils.debounce(200, request_diagnostics_api_wrapper)

---@param dispatchers Dispatchers
function M.setup_diagnostic_autocmds(dispatchers)
  local augroup = vim.api.nvim_create_augroup("TypescriptToolsDiagnosticGroup", { clear = true })

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
    common.create_lsp_attach_augcmd(function()
      request_diagnostics_debounced()

      api.nvim_create_autocmd("InsertEnter", {
        pattern = M.extensions_pattern,
        callback = function(e)
          proto_utils.publish_diagnostics(dispatchers, vim.uri_from_bufnr(e.buf), {})
        end,
        group = augroup,
      })

      api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
        pattern = M.extensions_pattern,
        callback = request_diagnostics_debounced,
        group = augroup,
      })
    end, augroup)
  end
end

return M
