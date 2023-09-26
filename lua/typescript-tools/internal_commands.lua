local api = vim.api

local c = require "typescript-tools.protocol.constants"
local plugin_api = require "typescript-tools.api"

local M = {}

--- @param params table
--- @param callback function
--- @param notify_reply_callback function
function M.handle_command(params, callback, notify_reply_callback)
  local command = params.command
  local command_handler = M[command]

  if command_handler then
    vim.schedule(function()
      command_handler(params)

      notify_reply_callback(command)
      callback(nil, nil)
    end)
  end

  return true, command
end

--- @param params table
M[c.InternalCommands.InvokeAdditionalRename] = function(params)
  local pos = params.arguments[2]

  api.nvim_win_set_cursor(0, { pos.line, pos.offset - 1 })

  -- INFO: wait just a bit to cursor move and then call rename
  vim.defer_fn(function()
    vim.lsp.buf.rename()
  end, 100)
end

M[c.InternalCommands.CallApiFunction] = function(params)
  local api_function = params.arguments[1]

  if api_function then
    plugin_api[api_function]()
  else
    vim.notify(
      "Unknown 'typescript-tools.api." .. api_function .. "' function!",
      vim.log.levels.WARN
    )
  end
end

M[c.InternalCommands.RequestReferences] = function(params)
  vim.lsp.buf_request(0, c.LspMethods.Reference, params.arguments)
end

M[c.InternalCommands.RequestImplementations] = function(params)
  vim.lsp.buf_request(0, c.LspMethods.Implementation, params.arguments)
end

return M
