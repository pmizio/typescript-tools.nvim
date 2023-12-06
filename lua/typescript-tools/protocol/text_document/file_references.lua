local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L901
  request {
    command = c.CommandTypes.FileReferences,
    arguments = { file = vim.uri_to_fname(text_document.uri) },
  }

  local body = coroutine.yield()

  if not body then
    return {}
  end

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L914
  response(utils.tsserver_location_response(body.refs or {}))
end

return M
