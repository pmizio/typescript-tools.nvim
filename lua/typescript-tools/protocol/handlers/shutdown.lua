local constants = require "typescript-tools.protocol.constants"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1371
local shutdown_request_handler = function()
  return { command = constants.CommandTypes.Exit }
end

return {
  request = { method = constants.LspMethods.Shutdown, handler = shutdown_request_handler },
}
