local constants = require "typescript-tools.protocol.constants"
local api = require "typescript-tools.api"

local M = {}

--- @return nil
M.setup_user_commands = function()
  vim.api.nvim_create_user_command("TSToolsOrganizeImports", function()
    api.organize_imports(constants.OrganizeImportsMode.All)
  end, {})

  vim.api.nvim_create_user_command("TSToolsSortImports", function()
    api.organize_imports(constants.OrganizeImportsMode.SortAndCombine)
  end, {})

  vim.api.nvim_create_user_command("TSToolsRemoveUnusedImports", function()
    api.organize_imports(constants.OrganizeImportsMode.RemoveUnused)
  end, {})
end

return M
