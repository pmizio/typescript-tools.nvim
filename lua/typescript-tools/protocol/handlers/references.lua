local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L852
local references_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.References,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L898
local references_response_handler = function(_, body, params)
  local references = body.refs

  if not params.context or not params.context.includeDeclaration then
    references = vim.tbl_filter(function(reference)
      return not reference.isDefinition
    end, references)
  end

  return vim.tbl_map(function(reference)
    return {
      uri = vim.uri_from_fname(reference.file),
      range = utils.convert_tsserver_range_to_lsp(reference),
    }
  end, references)
end

return {
  request = { method = constants.LspMethods.Reference, handler = references_request_handler },
  response = {
    method = constants.CommandTypes.References,
    handler = references_response_handler,
  },
}
