local c = require "typescript-tools.protocol.constants"
local api = require "typescript-tools.api"

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

  vim.api.nvim_create_user_command("TSToolsRemoveUnused", function()
    api.remove_unused()
  end, {})

  vim.api.nvim_create_user_command("TSToolsAddMissingImports", function()
    api.add_missing_imports()
  end, {})

  vim.api.nvim_create_user_command("TSToolsFixAll", function()
    api.fix_all()
  end, {})
end

return M
