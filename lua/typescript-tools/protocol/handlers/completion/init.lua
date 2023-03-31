local constants = require "typescript-tools.protocol.constants"
local item_kind_utils = require "typescript-tools.protocol.handlers.completion.item_kind_utils"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https//github.com/microsoft/TypeScript/blob/8b482b513d87c6fcda8ece18b99f8a01cff5c605/lib/protocol.d.ts#L1631
local completion_request_handler = function(_, params)
  local text_document = params.textDocument
  local context = params.context or {}
  local trigger_character = context.triggerCharacter

  return {
    command = constants.CommandTypes.CompletionInfo,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      triggerKind = context.triggerKind,
      triggerCharacter = vim.tbl_contains(constants.CompletionsTriggerCharacter, trigger_character)
          and trigger_character
        or nil,
      includeExternalModuleExports = true,
      includeInsertTextCompletions = true,
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1824
local calculate_text_edit = function(replacement_span, newText)
  if not replacement_span then
    return nil
  end

  local replacement_range = utils.convert_tsserver_range_to_lsp(replacement_span)

  return {
    newText = newText,
    insert = replacement_range,
    replace = replacement_range,
  }
end

local completion_response_handler = function(_, body, request_params)
  if not body then
    return {}
  end

  local file = vim.uri_to_fname(request_params.textDocument.uri)

  return {
    isIncomplete = body.isIncomplete or false,
    items = vim.tbl_map(function(item)
      local is_optional = item.kindModifiers
          and string.find(item.kindModifiers, "optional", 1, true)
        or false
      local is_deprecated = item.kindModifiers
          and string.find(item.kindModifiers, "deprecated", 1, true)
        or false
      local insertText = item.insertText or item.name
      local kind = item_kind_utils.map_completion_item_kind(item.kind)
      local sortText = item.sortText

      -- De-prioritze auto-imports if hasAction or source exists
      -- https://github.com/Microsoft/vscode/issues/40311
      if item.hasAction and item.source then
        sortText = "\u{ffff}" .. item.sortText
      end

      return {
        label = is_optional and (item.name .. "?") or item.name,
        labelDetails = item.labelDetails,
        insertText = insertText,
        filterText = insertText,
        commitCharacters = item_kind_utils.calculate_commit_characters(kind),
        kind = kind,
        insertTextFormat = item.isSnippet and constants.InsertTextFormat.Snippet
          or constants.InsertTextFormat.PlainText,
        sortText = sortText,
        textEdit = calculate_text_edit(item.replacementSpan, insertText),
        -- for now lsp support only one tag - deprecated - 1
        tags = is_deprecated and { 1 } or nil,
        data = vim.tbl_extend("force", {
          file = file,
          entryNames = {
            (item.source or item.data) and {
              name = item.name,
              source = item.source,
              data = item.data,
            } or item.name,
          },
        }, request_params.position),
      }
    end, body.entries or {}),
  }
end

return {
  request = { method = constants.LspMethods.Completion, handler = completion_request_handler },
  response = {
    method = constants.CommandTypes.CompletionInfo,
    handler = completion_response_handler,
  },
}
