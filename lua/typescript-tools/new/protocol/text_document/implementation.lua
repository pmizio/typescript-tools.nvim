local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function implementation_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L684
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.Implementation,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L761
  ---@param body table
  ---@return table
  local function handler(body)
    return vim.tbl_map(function(definition)
      return {
        uri = vim.uri_from_fname(definition.file),
        range = utils.convert_tsserver_range_to_lsp(definition),
      }
    end, body)
  end

  return request, handler
end

return implementation_creator
