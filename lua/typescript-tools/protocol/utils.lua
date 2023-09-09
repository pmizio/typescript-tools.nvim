local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"

local M = {}

local language_id_to_script_kind = {
  typescript = c.ScriptKindName.TS,
  typescriptreact = c.ScriptKindName.TSX,
  javascript = c.ScriptKindName.JS,
  javascriptreact = c.ScriptKindName.JSX,
}

local symbol_kind_map = {
  [c.ScriptElementKind.moduleElement] = c.SymbolKind.Module,
  [c.ScriptElementKind.classElement] = c.SymbolKind.Class,
  [c.ScriptElementKind.localClassElement] = c.SymbolKind.Class,
  [c.ScriptElementKind.interfaceElement] = c.SymbolKind.Interface,
  [c.ScriptElementKind.typeElement] = c.SymbolKind.TypeParameter,
  [c.ScriptElementKind.enumElement] = c.SymbolKind.Enum,
  [c.ScriptElementKind.enumMemberElement] = c.SymbolKind.EnumMember,
  [c.ScriptElementKind.variableElement] = c.SymbolKind.Variable,
  [c.ScriptElementKind.localVariableElement] = c.SymbolKind.Variable,
  [c.ScriptElementKind.functionElement] = c.SymbolKind.Function,
  [c.ScriptElementKind.localFunctionElement] = c.SymbolKind.Function,
  [c.ScriptElementKind.memberFunctionElement] = c.SymbolKind.Method,
  [c.ScriptElementKind.memberGetAccessorElement] = c.SymbolKind.Method,
  [c.ScriptElementKind.memberSetAccessorElement] = c.SymbolKind.Method,
  [c.ScriptElementKind.memberVariableElement] = c.SymbolKind.Property,
  [c.ScriptElementKind.constructorImplementationElement] = c.SymbolKind.Constructor,
  [c.ScriptElementKind.constructSignatureElement] = c.SymbolKind.Constructor,
  [c.ScriptElementKind.parameterElement] = c.SymbolKind.Variable,
  [c.ScriptElementKind.typeParameterElement] = c.SymbolKind.TypeParameter,
  [c.ScriptElementKind.constElement] = c.SymbolKind.Constant,
  [c.ScriptElementKind.letElement] = c.SymbolKind.Variable,
  [c.ScriptElementKind.externalModuleName] = c.SymbolKind.Module,
  [c.ScriptElementKind.jsxAttribute] = c.SymbolKind.Property,
  [c.ScriptElementKind.alias] = c.SymbolKind.Variable,
}

---@param text_document TextDocument
---@return string
function M.get_text_document_script_kind(text_document)
  return language_id_to_script_kind[text_document.languageId]
end

---@param position LspPosition
---@return TssPosition
function M.convert_lsp_position_to_tsserver(position)
  return {
    line = position.line + 1,
    offset = position.character + 1,
  }
end

---@param range LspRange
---@return TssRange
function M.convert_lsp_range_to_tsserver(range)
  return {
    start = M.convert_lsp_position_to_tsserver(range.start),
    ["end"] = M.convert_lsp_position_to_tsserver(range["end"]),
  }
end

---@param position TssPosition
---@return LspPosition
function M.convert_tsserver_position_to_lsp(position)
  -- line and offset can be 0 when position is at the start of newly created file
  return {
    line = position.line == 0 and 0 or position.line - 1,
    character = position.offset == 0 and 0 or position.offset - 1,
  }
end

---@param range TssRange
---@return LspRange
function M.convert_tsserver_range_to_lsp(range)
  return {
    start = M.convert_tsserver_position_to_lsp(range.start),
    ["end"] = M.convert_tsserver_position_to_lsp(range["end"]),
  }
end

---@param parts table
---@param delim string|nil
---@param tag_formatting boolean|nil
---@return string
function M.tsserver_docs_to_plain_text(parts, delim, tag_formatting)
  delim = delim or ""

  if type(parts) == "string" then
    return parts
  end

  return table.concat(vim.tbl_map(function(it)
    if tag_formatting and it.kind == "parameterName" then
      return "`" .. it.text .. "`"
    end

    return it.text
  end, parts) or {}, delim)
end

---@param tags table
---@return string
function M.tsserver_make_tags(tags)
  return table.concat(vim.tbl_map(function(it)
    local parts = { "\n_@" }
    table.insert(parts, it.name)
    if it.text then
      table.insert(parts, "_ — ")
      table.insert(parts, M.tsserver_docs_to_plain_text(it.text, nil, true))
    end

    return table.concat(parts, "")
  end, tags) or {}, "\n")
end

---@param script_element_kind any
---@return SymbolKind|nil
function M.get_lsp_symbol_kind(script_element_kind)
  local kind = symbol_kind_map[script_element_kind]

  if not kind then
    return c.SymbolKind.Variable
  end

  return kind
end

---@param edits table
---@return LspEdit
function M.convert_tsserver_edits_to_lsp(edits)
  local edits_per_file = {}

  for _, change in ipairs(edits) do
    local uri = vim.uri_from_fname(change.fileName)

    if not edits_per_file[uri] then
      edits_per_file[uri] = {}
    end

    for _, edit in ipairs(change.textChanges) do
      table.insert(edits_per_file[uri], {
        newText = edit.newText,
        range = M.convert_tsserver_range_to_lsp(edit),
      })
    end
  end

  return edits_per_file
end

---@param item table
---@return CallHierarchyItem
function M.convert_tsserver_call_hierarchy_item_to_lsp(item)
  return {
    name = item.name,
    kind = M.get_lsp_symbol_kind(item.kind),
    uri = vim.uri_from_fname(item.file),
    range = M.convert_tsserver_range_to_lsp(item.span),
    selectionRange = M.convert_tsserver_range_to_lsp(item.selectionSpan),
  }
end

---@param command CommandTypes
---@param params table
---@return TsserverRequest
function M.tsserver_location_request(command, params)
  local text_document = params.textDocument

  return {
    command = command,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, M.convert_lsp_position_to_tsserver(params.position)),
  }
end

---@param locations table
---@return table
function M.tsserver_location_response(locations)
  return vim.tbl_map(function(location)
    return {
      uri = vim.uri_from_fname(location.file),
      range = M.convert_tsserver_range_to_lsp(location),
    }
  end, locations)
end

---@param position number[]
---@param bufnr number
---@return number
function M.get_offset_at_position(position, bufnr)
  local line = position[1]
  local column = position[2]
  local err, line_offset = pcall(vim.api.nvim_buf_get_offset, bufnr, line)

  -- if line is negative or line is greater than file length
  if not err then
    return 0
  end

  return line_offset + column
end

---@param dispatchers Dispatchers
---@param file_uri string
---@param diagnostics Dispatchers
function M.publish_diagnostics(dispatchers, file_uri, diagnostics)
  dispatchers.notification(c.LspMethods.PublishDiagnostics, {
    uri = file_uri,
    diagnostics = diagnostics,
  })
end

---@param data table|nil
function M.cancelled_response(data)
  data = data or {}

  return {
    code = c.LspErrorCodes.RequestCancelled,
    data = data,
  }
end

---@param kind CompletionItemKind
---@param insertText string
---@param filetype vim.opt.filetype
---@return boolean
---@see https://github.com/typescript-language-server/typescript-language-server/blob/983a6923114c39d638e0c7d419ae16e8bca8985c/src/completion.ts#L355-L371
function M.should_create_function_snippet(kind, insertText, filetype)
  local preferences = plugin_config.get_tsserver_file_preferences(filetype)
  return preferences.includeCompletionsWithSnippetText
    and plugin_config.complete_function_calls
    and (kind == c.CompletionItemKind.Function or kind == c.CompletionItemKind.Method)
    and not string.find(insertText, "%$")
end

---@param content string
---@param kind "plaintext"|"markdown"|nil
function M.make_markup_content(content, kind)
  return {
    kind = kind or "markdown",
    value = content,
  }
end

return M
