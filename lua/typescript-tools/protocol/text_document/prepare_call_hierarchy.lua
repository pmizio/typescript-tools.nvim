local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

local islist = vim.islist or vim.tbl_islist

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2581
  request {
    command = c.CommandTypes.PrepareCallHierarchy,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2584
  local body = coroutine.yield()
  body = islist(body) and body or { body }

  response(vim.tbl_map(function(it)
    return utils.convert_tsserver_call_hierarchy_item_to_lsp(it)
  end, body))
end

return M
