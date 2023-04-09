local c = require "typescript-tools.protocol.constants"
local config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"

local M = {}

--- @return string[]
local function get_attached_buffers()
  local client = vim.lsp.get_active_clients({ name = config.NAME })[1]

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

---@param augroup number
function M.setup_diagnostic_autocmds(augroup)
  vim.api.nvim_create_autocmd("User", {
    pattern = {
      "TypescriptTools_" .. c.LspMethods.DidOpen,
      "TypescriptTools_" .. c.LspMethods.DidChange,
    },
    callback = function()
      local attached_bufs = get_attached_buffers()

      if #attached_bufs == 0 then
        return
      end

      vim.lsp.buf_request(0, c.CustomMethods.BatchDiagnostics, {
        files = attached_bufs,
      })
    end,
    group = augroup,
  })
end

return M
