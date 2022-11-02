local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- IncomingCalls:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2587
-- OutgoingCalls:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2593
local hierarchy_calls_request_handler = function(method, params)
  return {
    command = method == constants.LspMethods.IncomingCalls
        and constants.CommandTypes.ProvideCallHierarchyIncomingCalls
      or constants.CommandTypes.ProvideCallHierarchyOutgoingCalls,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(params.item.uri),
    }, utils.convert_lsp_position_to_tsserver(
      params.item.selectionRange.start
    )),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2590
-- OutgoingCalls:
-- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2596
local hierarchy_calls_response_handler = function(command, body)
  return vim.tbl_map(function(call)
    local lsp_call = {
      fromRanges = vim.tbl_map(function(it)
        return utils.convert_tsserver_range_to_lsp(it)
      end, call.fromSpans),
    }

    if command == constants.CommandTypes.ProvideCallHierarchyIncomingCalls then
      lsp_call.from = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.from)
    else
      lsp_call.to = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.to)
    end

    return lsp_call
  end, body)
end

return {
  request = {
    {
      method = constants.LspMethods.IncomingCalls,
      handler = hierarchy_calls_request_handler,
    },
    {
      method = constants.LspMethods.OutgoingCalls,
      handler = hierarchy_calls_request_handler,
    },
  },
  response = {
    {
      method = constants.CommandTypes.ProvideCallHierarchyIncomingCalls,
      handler = hierarchy_calls_response_handler,
    },
    {
      method = constants.CommandTypes.ProvideCallHierarchyOutgoingCalls,
      handler = hierarchy_calls_response_handler,
    },
  },
}
