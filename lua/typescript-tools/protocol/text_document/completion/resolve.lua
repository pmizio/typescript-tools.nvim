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

---@alias DisplayPart { kind: string, text: string }

---@param display_parts DisplayPart[]
---@return { has_optional_parameters: boolean, parts: DisplayPart[] }
---@see https://github.com/typescript-language-server/typescript-language-server/blob/983a6923114c39d638e0c7d419ae16e8bca8985c/src/completion.ts#L355-L371
local function get_parameter_list_parts(display_parts)
  local parts = {}
  local is_in_method = false
  local has_optional_parameters = false
  local paren_count = 0
  local brace_count = 0

  for i, part in ipairs(display_parts) do
    if
      part.kind == "methodName"
      or part.kind == "functionName"
      or part.kind == "text"
      or part.kind == "propertyName"
    then
      if paren_count == 0 and brace_count == 0 then
        is_in_method = true
      end
    elseif part.kind == "parameterName" then
      if paren_count == 1 and brace_count == 0 and is_in_method then
        local next = display_parts[i + 1]
        local name_is_followed_by_optional_indicator = next and next.text == "?"
        local name_is_this = part.text == "this"
        if not name_is_followed_by_optional_indicator and not name_is_this then
          table.insert(parts, part)
        end
        has_optional_parameters = has_optional_parameters or name_is_followed_by_optional_indicator
      end
    elseif part.kind == "punctuation" then
      if part.text == "(" then
        paren_count = paren_count + 1
      elseif part.text == ")" then
        paren_count = paren_count - 1
        if paren_count <= 0 and is_in_method then
          break
        end
      elseif part.text == "..." and paren_count == 1 then
        has_optional_parameters = true
        break
      elseif part.text == "{" then
        brace_count = brace_count + 1
      elseif part.text == "}" then
        brace_count = brace_count - 1
      end
    end
  end
  return { has_optional_parameters = has_optional_parameters, parts = parts }
end

---@alias PartialCompletionItem
---| { insertText: string, insertTextFormat: InsertTextFormat, textEdit: { newText: string }, label: string }

---@param item PartialCompletionItem
---@param display_parts DisplayPart[]
---@return nil
---@see https://github.com/typescript-language-server/typescript-language-server/blob/983a6923114c39d638e0c7d419ae16e8bca8985c/src/completion.ts#L355-L371
local function create_snippet(item, display_parts)
  local parameter_list_parts = get_parameter_list_parts(display_parts)
  local has_optional_parameters = parameter_list_parts.has_optional_parameters
  local parts = parameter_list_parts.parts
  local snippet =
    string.format("%s(", item.insertText or (item.textEdit and item.textEdit.newText) or item.label)
  for i, part in ipairs(parts) do
    local stop_index = (has_optional_parameters or i ~= #parts) and i or 0

    snippet = snippet .. string.format("${%d:%s}", stop_index, part.text:gsub("([$}\\])", "\\%1"))
    if i ~= #parts then
      snippet = snippet .. ", "
    end
  end
  if has_optional_parameters then
    snippet = snippet .. "$0"
  end
  snippet = snippet .. ")"
  item.insertText = snippet
  item.insertTextFormat = c.InsertTextFormat.Snippet
  if item.textEdit then
    item.textEdit.newText = snippet
  end
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
  local requested_bufnr = vim.uri_to_bufnr(vim.uri_from_fname(params.data.file))
  local filetype = vim.bo[requested_bufnr].filetype

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/549e61d0af1ba885be29d69f341e7d3a00686071/lib/protocol.d.ts#L1661
  request(completion_resolve_request(params))

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

    local item = vim.tbl_extend("force", params, {
      detail = detail,
      documentation = {
        kind = c.MarkupKind.Markdown,
        value = utils.tsserver_docs_to_plain_text(documentation, "\n"),
      },
      additionalTextEdits = make_text_edits(details.codeActions),
      -- INFO: there is also `command` prop but I don't know there is usecase for that here,
      -- or neovim even handle that for now i skip this
    })

    if utils.should_create_function_snippet(item.kind, item.insertText, filetype) then
      create_snippet(item, details.displayParts)
    end

    response(item)
  else
    response(nil)
  end
end

return M
