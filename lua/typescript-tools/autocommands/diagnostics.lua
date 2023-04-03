local api = vim.api
local lsp = vim.lsp

local config = require "typescript-tools.config"
local utils = require "typescript-tools.utils"
local constants = require "typescript-tools.protocol.constants"

local M = {}

--- @private
--- @return string[]
local function get_attached_buffers()
  local client = vim.lsp.get_active_clients({ name = config.NAME })[1]

  if client then
    local attached_bufs = {}

    for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
      if vim.lsp.buf_is_attached(bufnr, client.id) and not utils.is_buf_hidden(bufnr) then
        table.insert(attached_bufs, vim.uri_from_bufnr(bufnr))
      end
    end

    return attached_bufs
  end

  return {}
end

---@param tsserver_instance TsserverInstance
local function cancel_requests(tsserver_instance)
  tsserver_instance.request_queue:clear_geterrs()

  for _, it in pairs(tsserver_instance.request_metadata) do
    if it.message.command == constants.CommandTypes.Geterr and it.params.cancellable then
      tsserver_instance.rpc:cancel(it.seq)
    end
  end
end

--- @private
---@param tsserver_instance TsserverInstance
---@param low_priority boolean|nil
local debounced_request = utils.debounce(200, function(tsserver_instance, low_priority)
  local attached_bufs = get_attached_buffers()

  if #attached_bufs <= 0 then
    return
  end

  cancel_requests(tsserver_instance)
  lsp.buf_request(0, constants.CustomMethods.BatchDiagnostic, {
    files = attached_bufs,
    -- INFO: mark only internal diagnostics requests as cancellable,
    -- to prevent userspace requests cancellation
    cancellable = true,
    low_priority = low_priority,
  })
end)

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

  local sheduled_request = false
  local diag_augroup = api.nvim_create_augroup("TsserverDiagnosticsGroup", { clear = true })

  if config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.INSERT_LEAVE then
    api.nvim_create_autocmd("LspAttach", {
      callback = function()
        api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
          pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" },
          callback = function()
            if
              tsserver_instance.request_queue:has_command_queued(constants.CommandTypes.UpdateOpen)
            then
              sheduled_request = true
            else
              debounced_request(tsserver_instance)
            end
          end,
          group = diag_augroup,
        })
      end,
      group = diag_augroup,
    })
  end

  api.nvim_create_autocmd("User", {
    pattern = { "tsserver_response_" .. constants.CommandTypes.UpdateOpen },
    callback = function(event)
      local update_type = get_update_type(event.data)
      local is_initial_req = update_type == constants.CommandTypes.Open

      if
        sheduled_request
        or is_initial_req
        or (
          config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.CHANGE
          and update_type == constants.CommandTypes.Change
        )
      then
        debounced_request(tsserver_instance, is_initial_req)
        sheduled_request = false
      end
    end,
    group = diag_augroup,
  })
end

return M
