local diagnostics = require "typescript-tools.autocommands.diagnostics"

local M = {}

--- @param tsserver_instance TsserverInstance
function M.setup_autocmds(tsserver_instance)
  diagnostics.setup_autocmds(tsserver_instance)
end

return M
