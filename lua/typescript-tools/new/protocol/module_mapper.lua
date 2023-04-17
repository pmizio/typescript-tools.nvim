local c = require "typescript-tools.protocol.constants"

local remapped_methods = {
  [c.LspMethods.CompletionResolve] = "text_document.completion.resolve",
  [c.LspMethods.IncomingCalls] = "text_document.hierarchy_calls",
  [c.LspMethods.OutgoingCalls] = "text_document.hierarchy_calls",
  [c.LspMethods.CodeActionResolve] = "text_document.code_action.resolve",
  [c.LspMethods.RangeFormatting] = "text_document.formatting",
  [c.CustomMethods.BatchDiagnostics] = "text_document.batch_diagnostics",
}

local M = {}

local cache = {}

---@param method string
---@return string
function M.map_method_to_module(method)
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
