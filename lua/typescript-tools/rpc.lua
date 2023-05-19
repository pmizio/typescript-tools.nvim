local plugin_config = require "typescript-tools.config"
local c = require "typescript-tools.protocol.constants"
local Tsserver = require "typescript-tools.tsserver"
local autocommands = require "typescript-tools.autocommands"
local custom_handlers = require "typescript-tools.custom_handlers"
local request_router = require "typescript-tools.request_router"
local internal_commands = require "typescript-tools.internal_commands"
local locations_provider = require "typescript-tools.locations_provider"

local M = {}

---@param dispatchers Dispatchers
---@return LspInterface
function M.start(dispatchers)
  locations_provider:initialize()

  local tsserver_syntax = Tsserver:new("syntax", dispatchers)
  local tsserver_diagnostic = nil
  if plugin_config.separate_diagnostic_server then
    tsserver_diagnostic = Tsserver:new("diagnostic", dispatchers)
  end

  autocommands.setup_autocommands(dispatchers)
  custom_handlers.setup_lsp_handlers(dispatchers)

  return {
    request = function(method, ...)
      if method == c.LspMethods.ExecuteCommand then
        return internal_commands.handle_command(...)
      end

      return request_router.route_request(tsserver_syntax, tsserver_diagnostic, method, ...)
    end,
    notify = function(...)
      request_router.route_request(tsserver_syntax, tsserver_diagnostic, ...)
    end,
    terminate = function()
      tsserver_syntax:terminate()
      if tsserver_diagnostic then
        tsserver_diagnostic:terminate()
      end
    end,
    is_closing = function()
      local ret = tsserver_syntax:is_closing()
      if tsserver_diagnostic then
        ret = ret and tsserver_diagnostic:is_closing()
      end

      return ret
    end,
  }
end

return M
