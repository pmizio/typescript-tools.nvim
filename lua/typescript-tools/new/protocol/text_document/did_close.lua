local c = require "typescript-tools.protocol.constants"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L1305
---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function did_close_creator(_, params)
  local text_document = params.textDocument

  return {
    command = c.CommandTypes.UpdateOpen,
    arguments = {
      closedFiles = { vim.uri_from_fname(text_document.uri) },
      openFiles = {},
      changedFiles = {},
    },
  }
end

return did_close_creator
