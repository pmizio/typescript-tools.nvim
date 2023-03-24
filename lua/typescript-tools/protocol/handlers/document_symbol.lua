local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1440
local document_symbol_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.NavTree,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
    },
  }
end

--- @param symbols table
--- @return table
local function remove_aliases(symbols)
  return vim.tbl_filter(function(item)
    return item.kind ~= constants.ScriptElementKind.alias
  end, symbols)
end

local function map_document_symbol(item)
  return {
    name = item.text,
    kind = utils.get_lsp_symbol_kind(item.kind),
    children = vim.tbl_map(map_document_symbol, remove_aliases(item.childItems or {})),
    range = utils.convert_tsserver_range_to_lsp(item.spans[1]),
    selectionRange = item.nameSpan and utils.convert_tsserver_range_to_lsp(item.nameSpan)
      or utils.convert_tsserver_range_to_lsp(item.spans[1]),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L2561
local document_symbol_response_handler = function(_, body)
  if #body.childItems == 0 then
    return nil
  end

  return vim.tbl_map(map_document_symbol, remove_aliases(body.childItems))
end

return {
  request = {
    method = constants.LspMethods.DocumentSymbol,
    handler = document_symbol_request_handler,
  },
  response = { method = constants.CommandTypes.NavTree, handler = document_symbol_response_handler },
}
