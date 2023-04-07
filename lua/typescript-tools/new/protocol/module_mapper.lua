local c = require "typescript-tools.protocol.constants"

local REMAPPED_METHODS = {
  [c.LspMethods.CompletionResolve] = "text_document.completion.resolve",
}

local M = {}

---@param method string
---@return string
function M.map_method_to_module(method)
  local module = REMAPPED_METHODS[method]

  if module then
    return module
  end

  module = method:gsub("%$/", ""):gsub("/", "."):gsub("%u", function(it)
    return "_" .. it:lower()
  end)

  return module
end

return M
