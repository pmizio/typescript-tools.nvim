local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- OrganizeImports:
-- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L499
-- GetEditsForRefactor:
-- https://github.com/microsoft/TypeScript/blob/b0795e9c94757a8ee78077d160cde8819a9801ea/lib/protocol.d.ts#L469
local code_action_resolve_request_handler = function(_, params)
  local request = {
    arguments = params.data,
  }

  if params.kind == constants.CodeActionKind.SourceOrganizeImports then
    request.command = constants.CommandTypes.OrganizeImports
  else
    request.command = constants.CommandTypes.GetEditsForRefactor
  end

  return request
end

local get_edits = function(body, request_param)
  if request_param.kind == constants.CodeActionKind.SourceOrganizeImports then
    return utils.convert_tsserver_edits_to_lsp(body)
  end

  return utils.convert_tsserver_edits_to_lsp(body.edits)
end

-- tsserver protocol reference:
-- OrganizeImports:
-- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L508
-- GetEditsForRefactor:
-- https://github.com/microsoft/TypeScript/blob/b0795e9c94757a8ee78077d160cde8819a9801ea/lib/protocol.d.ts#L481
local code_action_resolve_response_handler = function(_, body, request_param)
  return {
    title = request_param.data.refactor,
    kind = request_param.data.kind,
    edit = {
      changes = get_edits(body, request_param),
    },
    command = body.renameFilename and {
      title = "Additional Rename",
      command = constants.InternalCommands.InvokeAdditionalRename,
      arguments = { body.renameFilename, body.renameLocation },
    } or nil,
  }
end

return {
  request = {
    method = constants.LspMethods.CodeActionResolve,
    handler = code_action_resolve_request_handler,
  },
  response = {
    {
      method = constants.CommandTypes.OrganizeImports,
      handler = code_action_resolve_response_handler,
    },
    {
      method = constants.CommandTypes.GetEditsForRefactor,
      handler = code_action_resolve_response_handler,
    },
  },
}
