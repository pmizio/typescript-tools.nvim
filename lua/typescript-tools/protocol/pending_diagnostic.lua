local c = require "typescript-tools.protocol.constants"

---@class PendingDiagnostic
---@field private request_metadata RequestContainer

---@class PendingDiagnostic
local PendingDiagnostic = {}

---@param request_metadata RequestContainer
---@return PendingDiagnostic
function PendingDiagnostic:new(request_metadata)
  local obj = {
    request_metadata = request_metadata,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

---@param response table
---@return boolean
function PendingDiagnostic:handle_response(response)
  if self:is_diagnostic_event(response) then
    local handler = self.request_metadata.handler

    coroutine.resume(handler, response.body, response.event)

    if coroutine.status(handler) == "dead" then
      return true
    end
  end

  return false
end

---@private
---@param response table
---@return boolean
function PendingDiagnostic:is_diagnostic_event(response)
  if response.type ~= "event" then
    return false
  end

  local event = response.event

  return event == c.DiagnosticEventKind.SyntaxDiag
    or event == c.DiagnosticEventKind.SemanticDiag
    or event == c.DiagnosticEventKind.SuggestionDiag
    or event == c.DiagnosticEventKind.RequestCompleted
end

---@return number
function PendingDiagnostic:get_seq()
  return self.request_metadata.context.seq
end

return PendingDiagnostic
