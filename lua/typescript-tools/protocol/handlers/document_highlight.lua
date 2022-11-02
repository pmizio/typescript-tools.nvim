local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L818
local document_highlight_request_handler = function(_, params)
  local text_document = params.textDocument
  local file = vim.uri_to_fname(text_document.uri)

  return {
    command = constants.CommandTypes.DocumentHighlights,
    arguments = vim.tbl_extend("force", {
      file = file,
      filesToSearch = { file },
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

local kind_map = {
  [constants.HighlightSpanKind.none] = constants.DocumentHighlightKind.Text,
  [constants.HighlightSpanKind.definition] = constants.DocumentHighlightKind.Write,
  [constants.HighlightSpanKind.reference] = constants.DocumentHighlightKind.Read,
  [constants.HighlightSpanKind.writtenReference] = constants.DocumentHighlightKind.Read,
}

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L844
local document_highlight_response_handler = function(_, body)
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

return {
  request = {
    method = constants.LspMethods.DocumentHighlight,
    handler = document_highlight_request_handler,
  },
  response = {
    method = constants.CommandTypes.DocumentHighlights,
    handler = document_highlight_response_handler,
  },
}
