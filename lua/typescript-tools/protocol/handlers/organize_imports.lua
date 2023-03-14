local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- OrganizeImports:
-- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L499
local code_action_resolve_request_handler = function(_, params)
  local file = params.file
  local skipDestructiveCodeActions = params.skipDestructiveCodeActions
  local request = {
    arguments = {
      scope = {
        args = {
          file = file,
        },
        type = "file",
      },
      skipDestructiveCodeActions = skipDestructiveCodeActions,
    },
    command = constants.CommandTypes.OrganizeImports,
  }

  return request
end

-- tsserver protocol reference:
-- OrganizeImports:
-- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L508
local code_action_resolve_response_handler = function(_, body, request_param)
  return {
    changes = utils.convert_tsserver_edits_to_lsp(body),
  }
end

return {
  request = {
    method = constants.CustomMethods.OrganizeImports,
    handler = code_action_resolve_request_handler,
  },
  response = {
    method = constants.CommandTypes.OrganizeImports,
    handler = code_action_resolve_response_handler,
  },
}
