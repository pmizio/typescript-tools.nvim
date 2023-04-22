local c = require "typescript-tools.new.protocol.constants"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1371
---@return TsserverRequest | TsserverRequest[], function|nil
local function shutdown_creator()
  return { command = c.CommandTypes.Exit }
end

return shutdown_creator
