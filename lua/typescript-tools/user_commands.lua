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

--- @param mode string
--- @return function
local function send_organize_import_request(mode)
  return function()
    local params = { file = vim.fn.expand "%p", mode = mode }

    vim.lsp.buf_request(0, constants.CustomMethods.OrganizeImports, params, function(_, result)
      apply_workspace_edit(result)
    end)
  end
end

--- @return nil
M.setup_user_commands = function()
  vim.api.nvim_create_user_command(
    "TSToolsOrganizeImports",
    send_organize_import_request(constants.OrganizeImportsMode.All),
    {}
  )
  vim.api.nvim_create_user_command(
    "TSToolsSortImports",
    send_organize_import_request(constants.OrganizeImportsMode.SortAndCombine),
    {}
  )
  vim.api.nvim_create_user_command(
    "TSToolsRemoveUnusedImports",
    send_organize_import_request(constants.OrganizeImportsMode.RemoveUnused),
    {}
  )
end

return M
