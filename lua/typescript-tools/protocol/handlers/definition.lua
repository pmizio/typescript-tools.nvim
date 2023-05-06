local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local file_span_with_context_to_location_link = function(file_span, text_span)
  local originSelectionRange = text_span and utils.convert_tsserver_range_to_lsp(text_span) or nil
  local target = {
    uri = vim.uri_from_fname(file_span.file),
    range = utils.convert_tsserver_range_to_lsp(file_span),
  }
  local targetRange = file_span.contextStart
      and file_span.contextEnd
      and utils.convert_tsserver_range_to_lsp {
        start = file_span.contextStart,
        ["end"] = file_span.contextEnd,
      }
    or target.range

  return {
    originSelectionRange = originSelectionRange,
    targetRange = targetRange,
    targetUri = target.uri,
    targetSelectionRange = target.range,
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L662
local definition_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.DefinitionAndBoundSpan,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L668
local definition_response_handler = function(_, body)
  return vim.tbl_map(function(definition)
    return file_span_with_context_to_location_link(definition, body.textSpan)
  end, body.definitions)
end

return {
  request = { method = constants.LspMethods.Definition, handler = definition_request_handler },
  response = {
    method = constants.CommandTypes.DefinitionAndBoundSpan,
    handler = definition_response_handler,
  },
}
