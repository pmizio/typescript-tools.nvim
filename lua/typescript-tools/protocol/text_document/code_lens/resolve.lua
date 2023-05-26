local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

M.low_priority = true
M.cancel_on_change = true

---@param n number
---@return number
local function render_number(n)
  return n > 0 and n - 1 or n
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local implementations = params.data.implementations
  local request_params = {
    textDocument = params.data.textDocument,
    position = params.range.start,
  }

  local title = ""
  local arguments = {}

  if implementations then
    request(utils.tsserver_location_request(c.CommandTypes.Implementation, request_params))

    local body = coroutine.yield()

    if body then
      title = "implementations: " .. render_number(#body)
      arguments = {
        textDocument = params.data.textDocument,
        position = params.range.start,
      }
    end
  else
    request(utils.tsserver_location_request(c.CommandTypes.References, request_params))

    local body = coroutine.yield()

    if body.refs then
      title = "references: " .. render_number(#body.refs)
      arguments = {
        textDocument = params.data.textDocument,
        position = params.range.start,
      }
    end
  end

  if title == "" then
    response(nil)
    return
  end

  response {
    range = params.range,
    command = {
      title = title,
      command = implementations and c.InternalCommands.RequestImplementations
        or c.InternalCommands.RequestReferences,
      arguments = arguments,
    },
  }
end

return M
