local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

local kind_map = {
  [c.HighlightSpanKind.none] = c.DocumentHighlightKind.Text,
  [c.HighlightSpanKind.definition] = c.DocumentHighlightKind.Write,
  [c.HighlightSpanKind.reference] = c.DocumentHighlightKind.Read,
  [c.HighlightSpanKind.writtenReference] = c.DocumentHighlightKind.Read,
}

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function document_highlight_creator(_, params)
  local text_document = params.textDocument
  local file = vim.uri_to_fname(text_document.uri)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L818
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.DocumentHighlights,
    arguments = vim.tbl_extend("force", {
      file = file,
      filesToSearch = { file },
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L844
  ---@param body table
  ---@return table|nil
  local function handler(body)
    if not body[1] then
      return nil
    end

    return vim.tbl_map(function(item)
      return {
        range = utils.convert_tsserver_range_to_lsp(item),
        kind = kind_map[item.kind],
      }
    end, body[1].highlightSpans)
  end

  return request, handler
end

return document_highlight_creator
