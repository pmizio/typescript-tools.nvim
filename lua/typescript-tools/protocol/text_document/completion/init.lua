local c = require "typescript-tools.protocol.constants"
local item_kind_utils = require "typescript-tools.protocol.text_document.completion.item_kind_utils"
local utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

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

local function calculate_member_completion_context(body, params)
  if body.isMemberCompletion then
    local line =
      vim.api.nvim_buf_get_lines(0, params.position.line, params.position.line + 1, false)[1]
    local dotAccessText = string.match(line:sub(1, params.position.character), "%??%.s*$") or nil
    if dotAccessText then
      local startPosition = {
        line = params.position.line,
        character = params.position.character - string.len(dotAccessText),
      }
      local range = { start = startPosition, ["end"] = params.position }
      local text = vim.api.nvim_buf_get_text(
        0,
        range.start.line,
        range.start.character,
        range["end"].line,
        range["end"].character,
        {}
      )
      return { dotAccessRange = range, dotAccessText = table.concat(text, "") }
    end
  end
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  local context = params.context or {}
  local trigger_character = context.triggerCharacter
  local requested_bufnr = vim.uri_to_bufnr(text_document.uri)
  local filetype = vim.bo[requested_bufnr].filetype

  -- tsserver protocol reference:
  -- https//github.com/microsoft/TypeScript/blob/8b482b513d87c6fcda8ece18b99f8a01cff5c605/lib/protocol.d.ts#L1631
  request {
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

  vim.schedule(function()
    local file = vim.uri_to_fname(text_document.uri)
    local memberCompletionContext = calculate_member_completion_context(body, params)

    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1824
    response {
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
        local range = item.replacementSpan

        -- De-prioritze auto-imports if hasAction or source exists
        -- https://github.com/Microsoft/vscode/issues/40311
        if item.hasAction and item.source then
          sortText = "\u{ffff}" .. item.sortText
        end

        if
          plugin_config.include_completions_with_insert_text
          and body.isMemberCompletion
          and memberCompletionContext
          and not item.isSnippet
        then
          local newInsertText = memberCompletionContext.dotAccessText .. (insertText or item.label)
          item.filterText = newInsertText
          if not range then
            range = utils.convert_lsp_range_to_tsserver(memberCompletionContext.dotAccessRange)
            insertText = newInsertText
          end
        end

        local should_create_function_snippet = utils.should_create_function_snippet(kind, filetype)
        local should_create_snippet = item.isSnippet or should_create_function_snippet
        local label = is_optional and (item.name .. "?") or item.name
        label = should_create_function_snippet and (label .. "(...)") or label

        return {
          label = label,
          labelDetails = item.labelDetails,
          insertText = insertText,
          filterText = insertText,
          commitCharacters = item_kind_utils.calculate_commit_characters(kind),
          kind = kind,
          insertTextFormat = should_create_snippet and c.InsertTextFormat.Snippet
            or c.InsertTextFormat.PlainText,
          sortText = sortText,
          textEdit = calculate_text_edit(range, insertText),
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
  end)
end

return M
