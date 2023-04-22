local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

--- @param symbols table
--- @return table
local function remove_aliases(symbols)
  return vim.tbl_filter(function(item)
    return item.kind ~= c.ScriptElementKind.alias
  end, symbols)
end

--- @param item table
--- @return table
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

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function document_symbol_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1440
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.NavTree,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L2561
  ---@param body table
  ---@return table|nil
  local function handler(body)
    if #body.childItems == 0 then
      return nil
    end

    return vim.tbl_map(map_document_symbol, remove_aliases(body.childItems))
  end

  return request, handler
end

return document_symbol_creator
