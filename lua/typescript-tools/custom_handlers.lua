local constants = require "typescript-tools.protocol.constants"

local M = {}

--- @param workspace_edit table
--- @return nil
local function apply_workspace_edit(workspace_edit)
  if not workspace_edit or not workspace_edit.changes then
    return
  end

  vim.lsp.util.apply_workspace_edit(workspace_edit, "utf-8")
end

--- @private
--- @param notification function
--- @param diagnostic table
local publish_diagnostics = function(notification, diagnostic)
  vim.schedule(function()
    notification(constants.LspMethods.PublishDiagnostics, diagnostic)
  end)
end

--- @param dispatchers table
function M.setup_lsp_handlers(dispatchers)
  vim.lsp.handlers[constants.CustomMethods.OrganizeImports] = function(_, result)
    apply_workspace_edit(result)
  end

  vim.lsp.handlers[constants.LspMethods.Diagnostic] = vim.lsp.handlers[constants.LspMethods.Diagnostic]
    or function(_, response, request)
      if not response then
        return
      end

      publish_diagnostics(dispatchers.notification, {
        uri = request.params.textDocument.uri,
        diagnostics = response.items,
      })
    end

  vim.lsp.handlers[constants.CustomMethods.BatchDiagnostic] = function(_, response, request)
    if not response then
      return
    end

    for _, uri in pairs(request.params.files) do
      publish_diagnostics(dispatchers.notification, {
        uri = uri,
        diagnostics = response[uri] or {},
      })
    end
  end
end

return M
