local c = require "typescript-tools.protocol.constants"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, _, params)
  local text_document = params.textDocument

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L1305
  request {
    command = c.CommandTypes.UpdateOpen,
    arguments = {
      closedFiles = { vim.uri_from_fname(text_document.uri) },
      openFiles = {},
      changedFiles = {},
    },
  }
end

return M
