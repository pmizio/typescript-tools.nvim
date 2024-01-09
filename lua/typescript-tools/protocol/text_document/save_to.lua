local c = require "typescript-tools.protocol.constants"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/f57e5104a3e21e82cafb818b531c8ec54ec0baa0/src/server/protocol.ts#L3123
  request {
    command = c.CommandTypes.Saveto,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      tmpfile = params.tmpfile,
    },
  }

  coroutine.yield()

  response {}
end

return M
