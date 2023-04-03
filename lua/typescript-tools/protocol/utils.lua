local c = require "typescript-tools.protocol.constants"

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

M.get_text_document_script_kind = function(text_document)
  return language_id_to_script_kind[text_document.languageId]
end

M.convert_lsp_position_to_tsserver = function(position)
  return {
    line = position.line + 1,
    offset = position.character + 1,
  }
end

M.convert_lsp_range_to_tsserver = function(range)
  return {
    start = M.convert_lsp_position_to_tsserver(range.start),
    ["end"] = M.convert_lsp_position_to_tsserver(range["end"]),
  }
end

M.convert_tsserver_position_to_lsp = function(position)
  return {
    line = position.line - 1,
    character = position.offset - 1,
  }
end

M.convert_tsserver_range_to_lsp = function(range)
  return {
    start = M.convert_tsserver_position_to_lsp(range.start),
    ["end"] = M.convert_tsserver_position_to_lsp(range["end"]),
  }
end

M.tsserver_docs_to_plain_text = function(parts, delim, tag_formatting)
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

M.tsserver_make_tags = function(tags)
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

M.get_lsp_symbol_kind = function(script_element_kind)
  local kind = symbol_kind_map[script_element_kind]

  if kind then
    return kind
  end

  vim.schedule_wrap(vim.notify)(
    "Cannot find matching LSP script kind for: " .. script_element_kind,
    vim.log.levels.ERROR
  )
end

M.convert_tsserver_edits_to_lsp = function(edits)
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

M.convert_tsserver_call_hierarchy_item_to_lsp = function(item)
  return {
    name = item.name,
    kind = M.get_lsp_symbol_kind(item.kind),
    uri = vim.uri_from_fname(item.file),
    range = M.convert_tsserver_range_to_lsp(item.span),
    selectionRange = M.convert_tsserver_range_to_lsp(item.selectionSpan),
  }
end

--- @class HandlerCoroutine
--- @overload fun(...: any): any
--- @field co thread
M.HandlerCoroutine = {}

--- @param handler function
--- @return HandlerCoroutine
function M.HandlerCoroutine:new(handler)
  local obj = {}

  setmetatable(obj, self)
  self.__index = self
  self.__call = function(this, ...)
    if not this.co or coroutine.status(this.co) == "dead" then
      this.co = coroutine.create(handler)
      -- "eat" first call to proceed to first yield
      coroutine.resume(this.co)
    end

    local _, ret = coroutine.resume(this.co, ...)
    return ret
  end

  return obj
end

function M.HandlerCoroutine:status()
  return self.co and coroutine.status(self.co) or "dead"
end

return M
