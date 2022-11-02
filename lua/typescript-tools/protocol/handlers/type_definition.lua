local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L676
local type_definition_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.TypeDefinition,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L755
local type_definition_response_handler = function(_, body)
  return vim.tbl_map(function(definition)
    return {
      uri = vim.uri_from_fname(definition.file),
      range = utils.convert_tsserver_range_to_lsp(definition),
    }
  end, body)
end

return {
  request = {
    method = constants.LspMethods.TypeDefinition,
    handler = type_definition_request_handler,
  },
  response = {
    method = constants.CommandTypes.TypeDefinition,
    handler = type_definition_response_handler,
  },
}
