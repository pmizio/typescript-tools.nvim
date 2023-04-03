local constants = require "typescript-tools.protocol.constants"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L1305
local close_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.UpdateOpen,
    arguments = {
      closedFiles = { vim.uri_to_fname(text_document.uri) },
      openFiles = {},
      changedFiles = {},
    },
  }
end

return {
  request = { method = constants.LspMethods.DidClose, handler = close_request_handler },
}
