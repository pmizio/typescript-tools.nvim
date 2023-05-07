local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L852
  request(utils.tsserver_location_request(c.CommandTypes.References, params))

  local body = coroutine.yield()
  local references = body.refs

  if not params.context or not params.context.includeDeclaration then
    references = vim.tbl_filter(function(reference)
      return not reference.isDefinition
    end, references)
  end

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L898
  response(utils.tsserver_location_response(references))
end

return M
