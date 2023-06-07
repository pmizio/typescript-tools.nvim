local c = require "typescript-tools.protocol.constants"

local M = {}

---@enum route_type
local route_type = {
  syntax = "syntax",
  semantic = "semantic",
  both = "both",
}

local router_config = {
  [c.LspMethods.Initialize] = route_type.both,
  [c.LspMethods.DidOpen] = route_type.both,
  [c.LspMethods.DidChange] = route_type.both,
  [c.LspMethods.DidClose] = route_type.both,
  [c.LspMethods.Shutdown] = route_type.both,
  [c.LspMethods.SemanticTokensFull] = route_type.semantic,
  [c.CustomMethods.Diagnostic] = route_type.semantic,
}

---@param method LspMethods
---@return route_type
local function get_route_config(method)
  local cfg = router_config[method]
  if cfg ~= nil then
    return cfg
  end

  return route_type.syntax
end

---@param syntax Tsserver
---@param semantic Tsserver|nil
---@param method LspMethods
function M.route_request(syntax, semantic, method, ...)
  local cfg = not semantic and route_type.syntax or get_route_config(method)

  -- INFO: when request is sent to both servers then prefer syntax one and return it's id
  if semantic and cfg == route_type.both then
    semantic:handle_request(method, ...)
  end

  if semantic and cfg == route_type.semantic then
    return semantic:handle_request(method, ...)
  end

  if cfg == route_type.syntax or cfg == route_type.both then
    return syntax:handle_request(method, ...)
  end
end

return M
