local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L930
local rename_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.Rename,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      -- TODO: expose as options
      findInComments = false,
      findInStrings = false,
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L993
local formatNewName = function(newText, loc)
  local buf = { newText }

  if loc.prefixText then
    table.insert(buf, 1, loc.prefixText)
  end

  if loc.suffixText then
    table.insert(buf, loc.suffixText)
  end

  return table.concat(buf, "")
end

local convert_tsserver_locs_to_changes = function(locs, newText)
  local edits_per_file = {}

  for _, spanGroup in pairs(locs) do
    local uri = vim.uri_from_fname(spanGroup.file)

    edits_per_file[uri] = vim.tbl_map(function(loc)
      return {
        newText = formatNewName(newText, loc),
        range = utils.convert_tsserver_range_to_lsp(loc),
      }
    end, spanGroup.locs)
  end

  return edits_per_file
end

local rename_response_handler = function(_, body, request_param)
  if not body.info.canRename then
    return nil
  end

  return {
    changes = convert_tsserver_locs_to_changes(body.locs, request_param.newName),
  }
end

return {
  request = { method = constants.LspMethods.Rename, handler = rename_request_handler },
  response = { method = constants.CommandTypes.Rename, handler = rename_response_handler },
}
