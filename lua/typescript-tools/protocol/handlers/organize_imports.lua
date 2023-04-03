local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local function map_mode_to_skip_destructions(mode)
  return mode == constants.OrganizeImportsMode.SortAndCombine
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L692
local organize_imports_request_handler = function(_, params)
  local file = params.file
  -- OrganizeImportsMode was introduced in tsserver 4.9.0 - keeping skipDestructiveCodeActions for backwards compatibility
  local skipDestructiveCodeActions = map_mode_to_skip_destructions(params.mode)
  local request = {
    arguments = {
      scope = {
        args = {
          file = file,
        },
        type = "file",
      },
      skipDestructiveCodeActions = skipDestructiveCodeActions,
      mode = params.mode,
    },
    command = constants.CommandTypes.OrganizeImports,
  }

  return request
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L712
local organize_imports_response_handler = function(_, body)
  return {
    changes = utils.convert_tsserver_edits_to_lsp(body),
  }
end

return {
  request = {
    method = constants.CustomMethods.OrganizeImports,
    handler = organize_imports_request_handler,
  },
  response = {
    method = constants.CommandTypes.OrganizeImports,
    handler = organize_imports_response_handler,
  },
}
