local api = vim.api

local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"

local publish_diagnostic_mode = plugin_config.publish_diagnostic_mode

local M = {}

--- @return string[]
local function get_attached_buffers()
  local client = vim.lsp.get_active_clients({ name = plugin_config.plugin_name })[1]

  if client then
    local attached_bufs = {}

    for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
      if vim.lsp.buf_is_attached(bufnr, client.id) and not utils.is_buf_hidden(bufnr) then
        table.insert(attached_bufs, vim.api.nvim_buf_get_name(bufnr))
      end
    end

    return attached_bufs
  end

  return {}
end

local function request_diagnostics()
  local attached_bufs = get_attached_buffers()

  if #attached_bufs == 0 then
    return
  end

  vim.lsp.buf_request(0, c.CustomMethods.BatchDiagnostics, {
    files = attached_bufs,
  })
end

local request_diagnostics_throttled = utils.throttle(200, request_diagnostics)
local request_diagnostics_debounced = utils.debounce(200, request_diagnostics)

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
