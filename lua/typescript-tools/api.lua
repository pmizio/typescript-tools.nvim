local constants = require "typescript-tools.protocol.constants"

local M = {}

--- @param mode string - accepts require( "typescript-tools.protocol.constants" ).OrganizeImportsMode.*
--- @return function
function M.organize_imports(mode)
  local params = { file = vim.fn.expand "%p", mode = mode }

  vim.lsp.buf_request(0, constants.CustomMethods.OrganizeImports, params)
end

return M
