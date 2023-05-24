local c = require "typescript-tools.protocol.constants"

---@class PendingDiagnostic
---@field private request_metadata RequestContainer

---@class PendingDiagnostic
local PendingDiagnostic = {}

---@param request_metadata RequestContainer
---@return PendingDiagnostic
function PendingDiagnostic.new(request_metadata)
  local self = setmetatable({}, { __index = PendingDiagnostic })

  self.request_metadata = request_metadata

  return self
end

---@private
---@param response table
---@return boolean
local function is_diagnostic_event(response)
  if response.type ~= "event" then
    return false
  end

  local event = response.event

  return event == c.DiagnosticEventKind.SyntaxDiag
    or event == c.DiagnosticEventKind.SemanticDiag
    or event == c.DiagnosticEventKind.SuggestionDiag
    or event == c.DiagnosticEventKind.RequestCompleted
end

---@param response table
---@return boolean
function PendingDiagnostic:handle_response(response)
  if is_diagnostic_event(response) then
    local seq = response.body.request_seq

    -- INFO: when previous diagnostic request was cancelled and new handler get event from old one,
    -- we want to ignore this event and wait for new one
    if seq and seq ~= self:get_seq() then
      return false
    end

    local handler = self.request_metadata.handler

    coroutine.resume(handler, response.body, response.event)

    if coroutine.status(handler) == "dead" then
      return true
    end
  end

  return false
end

---@return number
function PendingDiagnostic:get_seq()
  return self.request_metadata.context.seq
end

return PendingDiagnostic
