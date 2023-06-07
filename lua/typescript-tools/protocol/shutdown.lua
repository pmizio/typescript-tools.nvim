local c = require "typescript-tools.protocol.constants"

local M = {}

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1371
---@TsserverProtocolHandler
function M.handler(request)
  request { command = c.CommandTypes.Exit }
end

return M
