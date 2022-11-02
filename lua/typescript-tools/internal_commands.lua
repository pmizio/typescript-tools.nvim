local api = vim.api

local constants = require "typescript-tools.protocol.constants"

local M = {}

--- @param params table
--- @param callback function
--- @param notify_reply_callback function
M.handle_command = function(params, callback, notify_reply_callback)
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
M[constants.InternalCommands.InvokeAdditionalRename] = function(params)
  local pos = params.arguments[2]

  api.nvim_win_set_cursor(0, { pos.line, pos.offset - 1 })

  -- INFO: wait just a bit to cursor move and then call rename
  vim.defer_fn(function()
    vim.lsp.buf.rename()
  end, 100)
end

return M
