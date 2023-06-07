local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params, ctx)
  -- tsserver protocol reference:
  -- IncomingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2587
  -- OutgoingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2593
  request {
    command = ctx.method == c.LspMethods.IncomingCalls
        and c.CommandTypes.ProvideCallHierarchyIncomingCalls
      or c.CommandTypes.ProvideCallHierarchyOutgoingCalls,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(params.item.uri),
    }, utils.convert_lsp_position_to_tsserver(params.item.selectionRange.start)),
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- IncomingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2590
  -- OutgoingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2596
  response(vim.tbl_map(function(call)
    local lsp_call = {
      fromRanges = vim.tbl_map(function(it)
        return utils.convert_tsserver_range_to_lsp(it)
      end, call.fromSpans),
    }

    if ctx.method == c.LspMethods.IncomingCalls then
      lsp_call.from = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.from)
    else
      lsp_call.to = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.to)
    end

    return lsp_call
  end, body))
end

return M
