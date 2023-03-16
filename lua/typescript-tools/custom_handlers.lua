local constants = require "typescript-tools.protocol.constants"
local M = {}

function M.setup_lsp_commands()
  -- luacheck:ignore 122
  vim.lsp.commands[constants.CustomMethods.OrganizeImports] = function() end
end

return M
