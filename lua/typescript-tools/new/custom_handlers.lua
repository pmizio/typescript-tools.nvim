local c = require "typescript-tools.protocol.constants"

local M = {}

---@param workspace_edit table
local function apply_workspace_edit(workspace_edit)
  if not workspace_edit or not workspace_edit.changes then
    return
  end

  vim.lsp.util.apply_workspace_edit(workspace_edit, "utf-8")
end

---@param dispatchers Dispatchers
function M.setup_lsp_handlers(dispatchers)
  vim.lsp.handlers[c.CustomMethods.OrganizeImports] = function(_, result)
    apply_workspace_edit(result)
  end

  vim.lsp.handlers[c.CustomMethods.BatchDiagnostics] = function(_, result)
    for file, diagnostics in pairs(result or {}) do
      dispatchers.notification(c.LspMethods.PublishDiagnostics, {
        uri = file,
        diagnostics = diagnostics,
      })
    end
  end
end

return M
