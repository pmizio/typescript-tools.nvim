local c = require "typescript-tools.new.protocol.constants"

local M = {}

---@enum route_type
local route_type = {
  syntax = "syntax",
  diagnostic = "diagnostic",
  both = "both",
}

local router_config = {
  [c.LspMethods.Initialize] = route_type.both,
  [c.LspMethods.DidOpen] = route_type.both,
  [c.LspMethods.DidChange] = route_type.both,
  [c.LspMethods.DidClose] = route_type.both,
  [c.LspMethods.Shutdown] = route_type.both,
  [c.CustomMethods.BatchDiagnostics] = route_type.diagnostic,
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
---@param diagnostic Tsserver|nil
---@param method LspMethods
function M.route_request(syntax, diagnostic, method, ...)
  local cfg = not diagnostic and route_type.syntax or get_route_config(method)

  -- INFO: when request is sent to both servers then prefer syntax one and return it's id
  if diagnostic and cfg == route_type.both then
    diagnostic:handle_request(method, ...)
  end

  if diagnostic and cfg == route_type.diagnostic then
    return diagnostic:handle_request(method, ...)
  end

  if cfg == route_type.syntax or cfg == route_type.both then
    return syntax:handle_request(method, ...)
  end
end

return M
