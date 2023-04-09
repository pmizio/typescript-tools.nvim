local c = require "typescript-tools.protocol.constants"

local M = {}

---@param dispatchers Dispatchers
function M.setup_lsp_handlers(dispatchers)
  vim.lsp.handlers[c.CustomMethods.BatchDiagnostics] = function(_, result)
    for file, diagnostics in pairs(result) do
      dispatchers.notification(c.LspMethods.PublishDiagnostics, {
        uri = file,
        diagnostics = diagnostics,
      })
    end
  end
end

return M
