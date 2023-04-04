local api = vim.api
local lsp = vim.lsp

local config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"
local constants = require "typescript-tools.protocol.constants"

local M = {}

--- @param client_id number
--- @return string[]
local function get_attached_buffers(client_id)
  local attached_bufs = {}

  for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
    if vim.lsp.buf_is_attached(bufnr, client_id) and not utils.is_buf_hidden(bufnr) then
      table.insert(attached_bufs, vim.uri_from_bufnr(bufnr))
    end
  end

  return attached_bufs
end

--- @param tsserver_instance TsserverInstance
--- @param seq number
local function cancel_request(tsserver_instance, seq)
  tsserver_instance.request_queue:clear_geterrs()
  tsserver_instance.rpc:cancel(seq)
end

--- @param message table
--- @return "open"|"change"|"close"|nil
local function get_update_type(message)
  local args = message.arguments

  if not args then
    return nil
  end

  if #args.openFiles > 0 then
    return constants.CommandTypes.Open
  elseif #args.changedFiles > 0 then
    return constants.CommandTypes.Change
  else
    return constants.CommandTypes.Close
  end
end

--- @param tsserver_instance TsserverInstance
function M.setup_autocmds(tsserver_instance)
  if tsserver_instance.server_type == constants.ServerCompositeType.Primary then
    return
  end

  local pending_request = nil

  --- @param low_priority boolean|nil
  local function request_diagnostics(low_priority)
    local client = vim.lsp.get_active_clients({ name = config.NAME })[1]
    if not client then
      return
    end

    local attached_bufs = get_attached_buffers(client.id)

    if #attached_bufs <= 0 then
      return
    end

    if pending_request then
      cancel_request(tsserver_instance, pending_request)
      pending_request = nil
    end

    pending_request = lsp.buf_request(0, constants.CustomMethods.BatchDiagnostic, {
      files = attached_bufs,
      -- INFO: mark only internal diagnostics requests as cancellable,
      -- to prevent userspace requests cancellation
      cancellable = true,
      low_priority = low_priority,
    }, function(...)
      pending_request = nil
      return vim.lsp.handlers[constants.CustomMethods.BatchDiagnostic](...)
    end)[client.id]
  end

  --- @type function(low_priority: boolean|nil): nil
  local debounced_request = utils.debounce(200, request_diagnostics)

  --- @type function(low_priority: boolean|nil): nil
  local throttled_request = utils.throttle(200, request_diagnostics)

  local sheduled_request = true
  local diag_augroup = api.nvim_create_augroup("TsserverDiagnosticsGroup", { clear = true })

  if config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.INSERT_LEAVE then
    api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufWinEnter" }, {
      pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" },
      callback = function()
        if
          tsserver_instance.request_queue:has_command_queued(constants.CommandTypes.UpdateOpen)
        then
          sheduled_request = true
        else
          debounced_request()
        end
      end,
      group = diag_augroup,
    })
  end

  api.nvim_create_autocmd("User", {
    pattern = { "tsserver_response_" .. constants.CommandTypes.UpdateOpen },
    callback = function(event)
      local update_type = get_update_type(event.data)
      local is_initial_req = update_type == constants.CommandTypes.Open

      if is_initial_req then
        request_diagnostics(is_initial_req)
      elseif update_type == constants.CommandTypes.Change then
        if config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.CHANGE then
          throttled_request()
        elseif sheduled_request then
          debounced_request()
          sheduled_request = false
        end
      end
    end,
    group = diag_augroup,
  })
end

return M
