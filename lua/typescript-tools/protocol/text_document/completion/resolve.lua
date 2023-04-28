local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param code_actions table
---@return table|nil
local function make_text_edits(code_actions)
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

---@param params table
---@return table
local function completion_resolve_request(params)
  local data = params.data

  if type(data) == "table" then
    return {
      command = c.CommandTypes.CompletionDetails,
      arguments = vim.tbl_extend("force", {
        file = data.file,
        entryNames = data.entryNames,
        source = data.source,
      }, utils.convert_lsp_position_to_tsserver(data)),
    }
  end

  return {
    command = c.CommandTypes.CompletionDetails,
    arguments = params.data,
  }
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/549e61d0af1ba885be29d69f341e7d3a00686071/lib/protocol.d.ts#L1661
  local seq = request(completion_resolve_request(params))

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/9a83f2551ded0d88a0ba0ec9af260f83eb3568cd/lib/protocol.d.ts#L1841
  if body and body[1] then
    local details = body[1]
    local documentation = details.documentation or {}

    if details.tags then
      table.insert(documentation, { text = utils.tsserver_make_tags(details.tags) })
    end

    local detail = utils.tsserver_docs_to_plain_text(details.displayParts)

    -- copied behavior from https://github.com/typescript-language-server/typescript-language-server/blob/70eae7e0885d9b5b7841cad3ba033f3c9c6955d2/src/completion.ts#LL496C18-L496C18
    local source = details.sourceDisplay or details.deprecatedSource
    if source and detail then
      detail = "Auto import from " .. utils.tsserver_docs_to_plain_text(source) .. "\n" .. detail
    end

    return response(
      seq,
      vim.tbl_extend("force", params, {
        detail = detail,
        documentation = {
          kind = c.MarkupKind.Markdown,
          value = utils.tsserver_docs_to_plain_text(documentation, "\n"),
        },
        additionalTextEdits = make_text_edits(details.codeActions),
        -- INFO: there is also `command` prop but I don't know there is usecase for that here,
        -- or neovim even handle that for now i skip this
      })
    )
  else
    return response(seq, nil)
  end
end

return M
