local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function definition_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L662
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.DefinitionAndBoundSpan,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L668
  ---@param body table
  ---@return table
  local function handler(body)
    return vim.tbl_map(function(definition)
      return {
        uri = vim.uri_from_fname(definition.file),
        range = utils.convert_tsserver_range_to_lsp(definition),
      }
    end, body.definitions)
  end

  return request, handler
end

return definition_creator
