local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function prepare_call_hierarchy_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2581
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.PrepareCallHierarchy,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/503604c884bd0557c851b11b699ef98cdb65b93b/lib/protocol.d.ts#L2584
  ---@param body table
  ---@return table
  local function handler(body)
    body = vim.tbl_islist(body) and body or { body }

    return vim.tbl_map(function(it)
      return utils.convert_tsserver_call_hierarchy_item_to_lsp(it)
    end, body)
  end

  return request, handler
end

return prepare_call_hierarchy_creator
