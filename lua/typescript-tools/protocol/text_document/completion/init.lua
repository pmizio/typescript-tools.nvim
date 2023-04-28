local c = require "typescript-tools.protocol.constants"
local item_kind_utils = require "typescript-tools.protocol.text_document.completion.item_kind_utils"
local utils = require "typescript-tools.protocol.utils"

---@param replacement_span table
---@param new_text string
local function calculate_text_edit(replacement_span, new_text)
  if not replacement_span then
    return nil
  end

  local replacement_range = utils.convert_tsserver_range_to_lsp(replacement_span)

  return {
    newText = new_text,
    insert = replacement_range,
    replace = replacement_range,
  }
end

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function completion_creator(_, params)
  local text_document = params.textDocument
  local context = params.context or {}
  local trigger_character = context.triggerCharacter

  -- tsserver protocol reference:
  -- https//github.com/microsoft/TypeScript/blob/8b482b513d87c6fcda8ece18b99f8a01cff5c605/lib/protocol.d.ts#L1631
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.CompletionInfo,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      triggerKind = context.triggerKind,
      triggerCharacter = vim.tbl_contains(c.CompletionsTriggerCharacter, trigger_character)
          and trigger_character
        or nil,
      includeExternalModuleExports = true,
      includeInsertTextCompletions = true,
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1824
  ---@param body table
  ---@return table
  local function handler(body)
    local file = vim.uri_to_fname(text_document.uri)

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
          insertTextFormat = item.isSnippet and c.InsertTextFormat.Snippet
            or c.InsertTextFormat.PlainText,
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
          }, params.position),
        }
      end, body.entries or {}),
    }
  end

  return request, handler
end

-- return completion_creator

local M = {}

function M.handler(request, response, params)
  local text_document = params.textDocument
  local context = params.context or {}
  local trigger_character = context.triggerCharacter

  -- tsserver protocol reference:
  -- https//github.com/microsoft/TypeScript/blob/8b482b513d87c6fcda8ece18b99f8a01cff5c605/lib/protocol.d.ts#L1631
  local seq = request {
    command = c.CommandTypes.CompletionInfo,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      triggerKind = context.triggerKind,
      triggerCharacter = vim.tbl_contains(c.CompletionsTriggerCharacter, trigger_character)
          and trigger_character
        or nil,
      includeExternalModuleExports = true,
      includeInsertTextCompletions = true,
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  local body = coroutine.yield()
  local file = vim.uri_to_fname(text_document.uri)

  response(seq, {
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
        insertTextFormat = item.isSnippet and c.InsertTextFormat.Snippet
          or c.InsertTextFormat.PlainText,
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
        }, params.position),
      }
    end, body.entries or {}),
  })

  return true
end

return M
