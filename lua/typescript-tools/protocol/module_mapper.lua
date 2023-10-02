local c = require "typescript-tools.protocol.constants"

local remapped_methods = {
  [c.LspMethods.CompletionResolve] = "text_document.completion.resolve",
  [c.LspMethods.IncomingCalls] = "text_document.hierarchy_calls",
  [c.LspMethods.OutgoingCalls] = "text_document.hierarchy_calls",
  [c.LspMethods.CodeActionResolve] = "text_document.code_action.resolve",
  [c.LspMethods.RangeFormatting] = "text_document.formatting",
  [c.LspMethods.SemanticTokensFull] = "text_document.semantic_tokens",
  [c.CustomMethods.OrganizeImports] = "text_document.organize_imports",
  [c.CustomMethods.Diagnostic] = "text_document.custom_diagnostic",
  [c.CustomMethods.BatchCodeActions] = "text_document.code_action.batch",
  [c.LspMethods.CodeLensResolve] = "text_document.code_lens.resolve",
  [c.CustomMethods.ConfigurePlugin] = "text_document.configure_plugin",
}

local noop_methods = { c.LspMethods.DidSave }
vim.tbl_add_reverse_lookup(noop_methods)

local M = {}

local cache = {}

---@param method string
---@return string|nil
function M.map_method_to_module(method)
  if noop_methods[method] then
    return nil
  end

  local module = remapped_methods[method] or cache[method]

  if module then
    return module
  end

  module = method:gsub("%$/", ""):gsub("/", "."):gsub("%u", function(it)
    return "_" .. it:lower()
  end)

  cache[method] = module

  return module
end

return M
