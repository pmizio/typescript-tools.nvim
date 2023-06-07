local diagnostics = require "typescript-tools.autocommands.diagnostics"

local M = {}

---@param dispatchers Dispatchers
function M.setup_autocommands(dispatchers)
  local group = vim.api.nvim_create_augroup("TypescriptToolsGroup", { clear = true })

  diagnostics.setup_diagnostic_autocmds(group, dispatchers)
end

return M
