local plugin_config = require "typescript-tools.config"
local c = require "typescript-tools.protocol.constants"
local Tsserver = require "typescript-tools.tsserver"
local autocommands = require "typescript-tools.autocommands"
local custom_handlers = require "typescript-tools.custom_handlers"
local request_router = require "typescript-tools.request_router"
local internal_commands = require "typescript-tools.internal_commands"

local M = {}

---@param dispatchers Dispatchers
---@return LspInterface
function M.start(dispatchers)
  local tsserver_syntax = Tsserver.new("syntax", dispatchers)
  local tsserver_semantic = nil
  if plugin_config.separate_diagnostic_server then
    tsserver_semantic = Tsserver.new("semantic", dispatchers)
  end

  autocommands.setup_autocommands(dispatchers)
  custom_handlers.setup_lsp_handlers(dispatchers)

  return {
    request = function(method, ...)
      if method == c.LspMethods.ExecuteCommand then
        return internal_commands.handle_command(...)
      end

      return request_router.route_request(tsserver_syntax, tsserver_semantic, method, ...)
    end,
    notify = function(...)
      return request_router.route_request(tsserver_syntax, tsserver_semantic, ...)
    end,
    terminate = function()
      tsserver_syntax:terminate()
      if tsserver_semantic then
        tsserver_semantic:terminate()
      end
    end,
    is_closing = function()
      local ret = tsserver_syntax:is_closing()
      if tsserver_semantic then
        ret = ret and tsserver_semantic:is_closing()
      end

      return ret
    end,
  }
end

return M
