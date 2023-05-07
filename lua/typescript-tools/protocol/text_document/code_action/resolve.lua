local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

---@param body table
---@param params table
---@return table
local function get_edits(body, params)
  if params.kind == c.CodeActionKind.SourceOrganizeImports then
    return utils.convert_tsserver_edits_to_lsp(body)
  end

  return utils.convert_tsserver_edits_to_lsp(body.edits)
end

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function code_action_resolve_creator(_, params)
  -- tsserver protocol reference:
  -- OrganizeImports:
  -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L499
  -- GetEditsForRefactor:
  -- https://github.com/microsoft/TypeScript/blob/b0795e9c94757a8ee78077d160cde8819a9801ea/lib/protocol.d.ts#L469

  ---@type TsserverRequest
  local request = {
    arguments = params.data,
  }

  if params.kind == c.CodeActionKind.SourceOrganizeImports then
    request.command = c.CommandTypes.OrganizeImports
  else
    request.command = c.CommandTypes.GetEditsForRefactor
  end

  -- tsserver protocol reference:
  -- OrganizeImports:
  -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L508
  -- GetEditsForRefactor:
  -- https://github.com/microsoft/TypeScript/blob/b0795e9c94757a8ee78077d160cde8819a9801ea/lib/protocol.d.ts#L481
  ---@param body table
  ---@return table
  local function handler(body)
    return {
      title = params.data.refactor,
      kind = params.data.kind,
      edit = {
        changes = get_edits(body, params),
      },
      command = body.renameFilename and {
        title = "Additional Rename",
        command = c.InternalCommands.InvokeAdditionalRename,
        arguments = { body.renameFilename, body.renameLocation },
      } or nil,
    }
  end

  return request, handler
end

return code_action_resolve_creator
