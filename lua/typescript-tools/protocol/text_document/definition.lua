local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L662
  request(utils.tsserver_location_request(c.CommandTypes.DefinitionAndBoundSpan, params))

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L668
  return response(utils.tsserver_location_response(body.definitions))
end

return M
