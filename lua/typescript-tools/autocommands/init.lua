local diagnostics = require "typescript-tools.autocommands.diagnostics"

local M = {}

function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("TypescriptToolsGroup", { clear = true })

  diagnostics.setup_diagnostic_autocmds(group)
end

return M
