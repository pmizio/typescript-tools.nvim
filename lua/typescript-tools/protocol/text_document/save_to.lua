local c = require "typescript-tools.protocol.constants"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L930
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
