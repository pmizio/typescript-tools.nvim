local api = vim.api
local a = require "plenary.async"

local c = require "typescript-tools.protocol.constants"
local plugin_api = require "typescript-tools.api"
local async = require "typescript-tools.async"
local integrations = require "typescript-tools.integrations"

local M = {}

--- @param params table
--- @param callback function
function M.handle_command(params, callback)
  local command = params.command
  local command_handler = M[command]

  if command_handler then
    vim.schedule(function()
      command_handler(params)

      callback(nil, nil)
    end)
  end

  return true, nil
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

M[c.InternalCommands.InteractiveCodeAction] = function(params)
  local request = unpack(params.arguments)
  a.void(function()
    ---@type string|boolean|nil
    local target_file

    local has_telescope = pcall(require, "telescope.actions")
    local has_snacks = pcall(require, "snacks")

    if has_telescope then
      local _, file = a.wrap(integrations.telescope_picker, 2)()
      target_file = file
    elseif has_snacks then
      local _, file = a.wrap(integrations.snacks_picker, 2)()
      target_file = file
    else
      vim.notify(
        "Telescope or snacks.nvim picker needs to be installed to call this integration",
        vim.log.levels.WARN
      )
      target_file = async.ui_input { prompt = "Move to file: " }
    end

    if target_file == nil or not vim.fn.filereadable(target_file) then
      vim.notify("This refactor require existing file", vim.log.levels.WARN)
      return
    end

    local err, result = async.buf_request_isomorphic(
      false,
      0,
      c.LspMethods.CodeActionResolve,
      vim.tbl_deep_extend(
        "force",
        request,
        { data = { interactiveRefactorArguments = { targetFile = target_file } } }
      )
    )

    if err or not result or not result.edit or (result.edit and vim.tbl_isempty(result.edit)) then
      vim.notify("No refactors available", vim.log.levels.WARN)
      return
    end

    vim.lsp.util.apply_workspace_edit(result.edit, "utf-16")
  end)()
end

return M
