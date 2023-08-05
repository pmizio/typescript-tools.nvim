local c = require "typescript-tools.protocol.constants"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1493
  request {
    command = c.CommandTypes.ConfigurePlugin,
    arguments = {
      pluginName = params.pluginName,
      configuration = params.configuration,
    },
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1574
  response(vim.tbl_map(function(unknown)
    print(unknown)
    return unknown
  end, body))
end

return M
