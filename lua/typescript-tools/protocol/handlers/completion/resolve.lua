local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/549e61d0af1ba885be29d69f341e7d3a00686071/lib/protocol.d.ts#L1661
local completion_resolve_request_handler = function(_, params)
  local data = params.data

  if type(data) == "table" then
    return {
      command = constants.CommandTypes.CompletionDetails,
      arguments = vim.tbl_extend("force", {
        file = data.file,
        entryNames = data.entryNames,
        source = data.source,
      }, utils.convert_lsp_position_to_tsserver(
        data
      )),
    }
  end

  return {
    command = constants.CommandTypes.CompletionDetails,
    arguments = params.data,
  }
end

local make_text_edits = function(code_actions)
  if not code_actions then
    return nil
  end

  local text_edits = {}

  for _, action in ipairs(code_actions) do
    for _, changes_set in ipairs(action.changes) do
      for _, change in ipairs(changes_set.textChanges) do
        table.insert(text_edits, {
          newText = change.newText,
          range = utils.convert_tsserver_range_to_lsp(change),
        })
      end
    end
  end

  return text_edits
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1841
local completion_resolve_response_handler = function(_, body, request_params)
  if body and body[1] then
    local details = body[1]
    local documentation = details.documentation or {}

    if details.tags then
      table.insert(documentation, { text = utils.tsserver_make_tags(details.tags) })
    end

    return vim.tbl_extend("force", request_params, {
      detail = utils.tsserver_docs_to_plain_text(details.displayParts),
      documentation = {
        kind = constants.MarkupKind.Markdown,
        value = utils.tsserver_docs_to_plain_text(documentation, "\n"),
      },
      additionalTextEdits = make_text_edits(details.codeActions),
      -- INFO: there is also `command` prop but I don't know there is usecase for that here,
      -- or neovim even handle that for now i skip this
    })
  end

  return nil
end

return {
  request = {
    method = constants.LspMethods.CompletionResolve,
    handler = completion_resolve_request_handler,
  },
  response = {
    method = constants.CommandTypes.CompletionDetails,
    handler = completion_resolve_response_handler,
  },
}
