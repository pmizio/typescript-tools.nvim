local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

local kind_map = {
  [c.HighlightSpanKind.none] = c.DocumentHighlightKind.Text,
  [c.HighlightSpanKind.definition] = c.DocumentHighlightKind.Write,
  [c.HighlightSpanKind.reference] = c.DocumentHighlightKind.Read,
  [c.HighlightSpanKind.writtenReference] = c.DocumentHighlightKind.Read,
}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  local file = vim.uri_to_fname(text_document.uri)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L818
  request {
    command = c.CommandTypes.DocumentHighlights,
    arguments = vim.tbl_extend("force", {
      file = file,
      filesToSearch = { file },
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L844
  if not body[1] then
    response(nil)
  end

  response(vim.tbl_map(function(item)
    return {
      kind = kind_map[item.kind],
      range = utils.convert_tsserver_range_to_lsp(item),
    }
  end, body[1].highlightSpans))
end

return M
