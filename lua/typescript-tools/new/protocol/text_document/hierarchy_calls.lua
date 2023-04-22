local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

---@param method string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function hierarchy_calls_creator(method, params)
  -- tsserver protocol reference:
  -- IncomingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2587
  -- OutgoingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2593
  ---@type TsserverRequest
  local request = {
    command = method == c.LspMethods.IncomingCalls
        and c.CommandTypes.ProvideCallHierarchyIncomingCalls
      or c.CommandTypes.ProvideCallHierarchyOutgoingCalls,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(params.item.uri),
    }, utils.convert_lsp_position_to_tsserver(params.item.selectionRange.start)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2590
  -- OutgoingCalls:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2596
  ---@param body table
  ---@return table
  local function handler(body)
    return vim.tbl_map(function(call)
      local lsp_call = {
        fromRanges = vim.tbl_map(function(it)
          return utils.convert_tsserver_range_to_lsp(it)
        end, call.fromSpans),
      }

      if method == c.LspMethods.IncomingCalls then
        lsp_call.from = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.from)
      else
        lsp_call.to = utils.convert_tsserver_call_hierarchy_item_to_lsp(call.to)
      end

      return lsp_call
    end, body)
  end

  return request, handler
end

return hierarchy_calls_creator
