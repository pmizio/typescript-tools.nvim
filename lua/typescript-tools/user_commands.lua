local c = require "typescript-tools.new.protocol.constants"
local api = require "typescript-tools.new.api"

local M = {}

function M.setup_user_commands()
  vim.api.nvim_create_user_command("TSToolsOrganizeImports", function()
    api.organize_imports(c.OrganizeImportsMode.All)
  end, {})

  vim.api.nvim_create_user_command("TSToolsSortImports", function()
    api.organize_imports(c.OrganizeImportsMode.SortAndCombine)
  end, {})

  vim.api.nvim_create_user_command("TSToolsRemoveUnusedImports", function()
    api.organize_imports(c.OrganizeImportsMode.RemoveUnused)
  end, {})
end

return M
