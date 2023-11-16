local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  request(utils.tsserver_location_request(c.CommandTypes.JsxClosingTag, params))

  local body = coroutine.yield()

  -- if execute failed will back a response include success field.
  if body.success == false then
    response {}
    return
  end

  response(body)
end

return M
