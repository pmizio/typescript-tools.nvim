local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2581
local prepare_call_hierarchy_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.PrepareCallHierarchy,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2584
local prepare_call_hierarchy_response_handler = function(_, body)
  body = vim.tbl_islist(body) and body or { body }

  local calls = vim.tbl_map(function(it)
    return utils.convert_tsserver_call_hierarchy_item_to_lsp(it)
  end, body)

  return calls
end

return {
  request = {
    method = constants.LspMethods.PrepareCallHierarchy,
    handler = prepare_call_hierarchy_request_handler,
  },
  response = {
    method = constants.CommandTypes.PrepareCallHierarchy,
    handler = prepare_call_hierarchy_response_handler,
  },
}
