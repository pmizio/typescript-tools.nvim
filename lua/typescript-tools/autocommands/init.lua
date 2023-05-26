local diagnostics = require "typescript-tools.autocommands.diagnostics"
local code_lens = require "typescript-tools.autocommands.code_lens"

local M = {}

---@param dispatchers Dispatchers
function M.setup_autocommands(dispatchers)
  diagnostics.setup_diagnostic_autocmds(dispatchers)
  code_lens.setup_code_lens_autocmds()
end

return M
