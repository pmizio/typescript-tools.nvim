local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

-- FileSpanWithContext https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L1034
-- LocationLink https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#locationLink
---@param file_span table
---@param origin_selection_range table
---@return table
local function file_span_with_context_to_location_link(file_span, origin_selection_range)
  local uri = file_span.file

  if not vim.startswith(uri, "zipfile://") then
    uri = vim.uri_from_fname(uri)
  end

  local range = utils.convert_tsserver_range_to_lsp(file_span)

  local target_range = file_span.contextStart
      and file_span.contextEnd
      and utils.convert_tsserver_range_to_lsp {
        start = file_span.contextStart,
        ["end"] = file_span.contextEnd,
      }
    or range

  return {
    originSelectionRange = origin_selection_range,
    targetRange = target_range,
    targetUri = uri,
    targetSelectionRange = range,
  }
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local command = params.context
      and params.context.source_definition
      and c.CommandTypes.FindSourceDefinition
    or c.CommandTypes.DefinitionAndBoundSpan

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L662
  request(utils.tsserver_location_request(command, params))

  local body = coroutine.yield()

  local origin_selection_range = body.textSpan
      and utils.convert_tsserver_range_to_lsp(body.textSpan)
    or nil

  local definitions = command == c.CommandTypes.FindSourceDefinition and body or body.definitions

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L668
  response(vim.tbl_map(function(definition)
    return file_span_with_context_to_location_link(definition, origin_selection_range)
  end, definitions))
end

return M
