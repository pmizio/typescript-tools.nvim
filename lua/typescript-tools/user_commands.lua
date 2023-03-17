local constants = require "typescript-tools.protocol.constants"
local api = require "typescript-tools.api"

local M = {}

--- @return nil
M.setup_user_commands = function()
  vim.api.nvim_create_user_command(
    "TSToolsOrganizeImports",
    api.organize_imports(constants.OrganizeImportsMode.All),
    {}
  )
  vim.api.nvim_create_user_command(
    "TSToolsSortImports",
    api.organize_imports(constants.OrganizeImportsMode.SortAndCombine),
    {}
  )
  vim.api.nvim_create_user_command(
    "TSToolsRemoveUnusedImports",
    api.organize_imports(constants.OrganizeImportsMode.RemoveUnused),
    {}
  )
end

return M
