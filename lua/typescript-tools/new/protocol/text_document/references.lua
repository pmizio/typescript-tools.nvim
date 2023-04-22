local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function references_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L852
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.References,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/45148dd715a7c3776840778b4df41e7e0bd0bf12/lib/protocol.d.ts#L898
  ---@param body table
  ---@return table
  local function handler(body)
    return vim.tbl_map(function(reference)
      return {
        uri = vim.uri_from_fname(reference.file),
        range = utils.convert_tsserver_range_to_lsp(reference),
      }
    end, body.refs)
  end

  return request, handler
end

return references_creator
