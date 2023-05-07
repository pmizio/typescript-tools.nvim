local c = require "typescript-tools.protocol.constants"

local M = {}

---@param mode OrganizeImportsMode
function M.organize_imports(mode)
  local params = { file = vim.api.nvim_buf_get_name(0), mode = mode }

  vim.lsp.buf_request(0, c.CustomMethods.OrganizeImports, params)
end

return M
