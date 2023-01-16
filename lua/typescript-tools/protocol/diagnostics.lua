local api = vim.api
local log = require "vim.lsp.log"
local constants = require "typescript-tools.protocol.constants"
local lspUtils = require "typescript-tools.protocol.utils"
local utils = require "typescript-tools.utils"
local config = require "typescript-tools.config"

local SOURCE = "tsserver"

local CANCEL_AND_RETRIGGER = {
  constants.CommandTypes.Open,
  constants.CommandTypes.Change,
  constants.CommandTypes.UpdateOpen,
  constants.CommandTypes.Close,
  constants.CommandTypes.CompletionInfo,
  constants.CommandTypes.CompletionDetails,
}

local severity_map = {
  suggestion = constants.DiagnosticSeverity.Hint,
  warning = constants.DiagnosticSeverity.Warning,
  error = constants.DiagnosticSeverity.Error,
}

vim.tbl_add_reverse_lookup(CANCEL_AND_RETRIGGER)

--- @class DiagnosticsService
--- @field server_type string
--- @field tsserver TsserverInstance
--- @field pending number|nil
--- @field diagnostics_cache table
--- @field dispatchers table
--- @field debounced_request function
--- @field timer_handle table

--- @class DiagnosticsService
local DiagnosticsService = {}

--- @param server_type string
--- @param tsserver TsserverInstance
--- @param dispatchers table
function DiagnosticsService:new(server_type, tsserver, dispatchers)
  local obj = {
    server_type = server_type,
    tsserver = tsserver,
    pending = nil,
    diagnostics_cache = {},
    dispatchers = dispatchers,
  }

  setmetatable(obj, self)
  self.__index = self

  if config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.INSERT_LEAVE then
    local augroup = api.nvim_create_augroup("TsserverDiagnosticsGroup", { clear = true })
    api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
      pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" },
      callback = function()
        obj:request()
      end,
      group = augroup,
    })
  end

  --- @private
  --- @return string[]
  local function get_attached_buffers()
    local client = vim.lsp.get_active_clients({ name = config.NAME })[1]

    if client then
      local attached_bufs = {}

      for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
        if vim.lsp.buf_is_attached(bufnr, client.id) and not utils.is_buf_hidden(bufnr) then
          table.insert(attached_bufs, vim.api.nvim_buf_get_name(bufnr))
        end
      end

      return attached_bufs
    end

    return {}
  end

  obj.debounced_request, obj.timer_handle = utils.debounce(200, function()
    local attached_bufs = get_attached_buffers()

    if #attached_bufs <= 0 then
      return
    end

    obj:cancel()
    obj:clear_cache(attached_bufs)

    obj.pending = obj.tsserver.request_queue:enqueue {
      message = {
        command = constants.CommandTypes.Geterr,
        arguments = {
          delay = 0,
          files = attached_bufs,
        },
      },
      -- INFO: use async only in single server mode
      is_async = obj.server_type == constants.ServerCompositeType.Single,
    }

    if obj.tsserver.request_queue:is_empty() then
      obj.tsserver:send_queued_requests()
    end
  end)

  return obj
end

--- @private
function DiagnosticsService:request()
  -- TODO: correctly handle one server scenario
  if self.server_type == constants.ServerCompositeType.Primary then
    return
  end

  self.debounced_request()
end

--- @private
function DiagnosticsService:cancel()
  self.tsserver.request_queue:clear_geterrs()

  if self.pending ~= nil then
    self.tsserver.rpc:cancel(self.pending)
    self.pending = nil
  end
end

--- @param message table
--- @return "open"|"change"|"close"
local function get_update_type(message)
  local command = message.command

  if
    command == constants.CommandTypes.Open
    or command == constants.CommandTypes.Change
    or command == constants.CommandTypes.Close
  then
    return command
  end

  if command == constants.CommandTypes.UpdateOpen then
    local args = message.arguments

    if #args.openFiles > 0 then
      return "open"
    elseif #args.changedFiles > 0 then
      return "change"
    else
      -- INFO: it is impossible to send all empty lists of changes
      return "close"
    end
  end
end

--- @private
--- @param files string[]
function DiagnosticsService:clear_cache(files)
  self.diagnostics_cache = {}

  for _, buf in pairs(files) do
    self.diagnostics_cache[buf] = {}
  end
end

--- @param message table
function DiagnosticsService:handle_request(message)
  local command = message.command

  if CANCEL_AND_RETRIGGER[command] then
    self:cancel()
  end

  local update_type = get_update_type(message)

  if
    update_type == "open"
    or (
      config.publish_diagnostic_on == config.PUBLISH_DIAGNOSTIC_ON.CHANGE
      and update_type == "change"
    )
  then
    self:request()
  end
end

--- @param category number
--- @return number
local category_to_severity = function(category)
  local severity = severity_map[category]
  if not severity then
    log.warn("[tsserver] cannot find correct severity for: " .. category)
    return constants.DiagnosticSeverity.Error
  end

  return severity
end

--- @private
--- @param related_information table
--- @return table
local convert_related_information = function(related_information)
  return vim.tbl_map(function(info)
    return {
      message = info.message,
      location = {
        uri = vim.uri_from_fname(info.span.file),
        range = lspUtils.convert_tsserver_range_to_lsp(info.span),
      },
    }
  end, related_information)
end

--- @private
--- @param response table
function DiagnosticsService:collect_diagnostics(response)
  for _, diagnostic in pairs(response.body.diagnostics) do
    table.insert(self.diagnostics_cache[response.body.file], {
      message = diagnostic.text,
      source = SOURCE,
      code = diagnostic.code,
      severity = category_to_severity(diagnostic.category),
      range = lspUtils.convert_tsserver_range_to_lsp(diagnostic),
      relatedInformation = diagnostic.relatedInformation and convert_related_information(
        diagnostic.relatedInformation
      ),
    })
  end
end

--- @private
--- @param response table
function DiagnosticsService:publish_diagnostics(response)
  if self.pending == response.body.request_seq then
    vim.schedule(function()
      for file, diagnostics in pairs(self.diagnostics_cache) do
        self.dispatchers.notification(constants.LspMethods.PublishDiagnostics, {
          uri = vim.uri_from_fname(file),
          diagnostics = diagnostics,
        })
      end
    end)

    self.pending = nil
  end
end

--- @param response table
function DiagnosticsService:handle_response(response)
  local event = response.event

  if
    event == constants.DiagnosticEventKind.SyntaxDiag
    or event == constants.DiagnosticEventKind.SemanticDiag
    or event == constants.DiagnosticEventKind.SuggestionDiag
  then
    self:collect_diagnostics(response)
  end

  if event == constants.RequestCompletedEventName then
    self:publish_diagnostics(response)
  end

  if CANCEL_AND_RETRIGGER[response.command] then
    self:request()
  end
end

function DiagnosticsService:dispose()
  self.timer_handle:close()
end

return DiagnosticsService
