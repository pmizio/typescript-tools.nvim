local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param mode OrganizeImportsMode
---@return boolean
local function map_mode_to_skip_destructions(mode)
  return mode == c.OrganizeImportsMode.SortAndCombine
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local file = params.file
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L692
  request {
    command = c.CommandTypes.OrganizeImports,
    arguments = {
      scope = {
        args = {
          file = file,
        },
        type = "file",
      },
      skipDestructiveCodeActions = map_mode_to_skip_destructions(params.mode),
      mode = params.mode,
    },
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L712
  response {
    changes = utils.convert_tsserver_edits_to_lsp(body),
  }
end

return M
