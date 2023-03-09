local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local make_text_edits = function(code_edits)
  if not code_edits then
    return nil
  end

  local changes = {}

  for _, code_edit in ipairs(code_edits) do
    local uri = vim.uri_from_fname(code_edit.fileName)
    local text_edits = changes[uri] or {}

    for _, text_change in ipairs(code_edit.textChanges) do
      local text_edit = {
        newText = text_change.newText,
        range = utils.convert_tsserver_range_to_lsp(text_change),
      }
      table.insert(text_edits, text_edit)
    end

    changes[uri] = text_edits
  end

  return changes
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L511
local request_handler = function(_, params)
  -- in params there could be multiple files but in order fulfill request
  -- with multiple files we would need to send multiple requests to tsserver
  -- at the moment there is no abstraction to do that so we just take first file
  local firstFile = params.files[1]
  local oldFilePath = vim.uri_to_fname(firstFile.oldUri)
  local newFilePath = vim.uri_to_fname(firstFile.newUri)

  return {
    command = constants.CommandTypes.GetEditsForFileRename,
    arguments = {
      oldFilePath = oldFilePath,
      newFilePath = newFilePath,
    },
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L511
local response_handler = function(_, params)
  return {
    changes = make_text_edits(params),
  }
end

return {
  request = { method = constants.LspMethods.WillRenameFiles, handler = request_handler },
  response = { method = constants.CommandTypes.GetEditsForFileRename, handler = response_handler },
}
