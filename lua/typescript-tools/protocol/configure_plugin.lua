local c = require "typescript-tools.protocol.constants"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, _, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1175
  request {
    command = c.CommandTypes.ConfigurePlugin,
    arguments = {
      pluginName = params.pluginName,
      configuration = params.configuration,
    },
  }

  -- INFO: response is empty we can ignore it but maybe it is worth to wait for it
  coroutine.yield()
end

return M
