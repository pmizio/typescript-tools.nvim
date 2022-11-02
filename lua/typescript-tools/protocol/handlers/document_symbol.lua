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

--- @param rest function
--- @return function
local function map_symbol(rest)
  return function(symbol)
    return vim.tbl_extend("force", {
      name = symbol.text,
      kind = utils.get_lsp_symbol_kind(symbol.kind),
    }, rest(
      symbol
    ))
  end
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L2561
local document_symbol_response_handler = function(_, body, request_param)
  local text_document = request_param.textDocument

  if #body.childItems == 0 then
    return nil
  end

  return vim.tbl_map(
    map_symbol(function(item)
      return {
        selectionRange = item.nameSpan and utils.convert_tsserver_range_to_lsp(item.nameSpan)
          or utils.convert_tsserver_range_to_lsp(item.spans[1]),
        range = utils.convert_tsserver_range_to_lsp(item.spans[1]),
        children = vim.tbl_map(
          map_symbol(function(child)
            return {
              containerName = item.text,
              location = {
                uri = text_document.uri,
                range = utils.convert_tsserver_range_to_lsp(child.spans[1]),
              },
            }
          end),
          remove_aliases(item.childItems or {})
        ),
      }
    end),
    remove_aliases(body.childItems)
  )
end

return {
  request = {
    method = constants.LspMethods.DocumentSymbol,
    handler = document_symbol_request_handler,
  },
  response = { method = constants.CommandTypes.NavTree, handler = document_symbol_response_handler },
}
