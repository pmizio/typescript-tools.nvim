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

function M.setup_lsp_commands()
  -- luacheck:ignore 122
  vim.lsp.handlers[constants.CustomMethods.OrganizeImports] = function(_, result)
    apply_workspace_edit(result)
  end
end

return M
