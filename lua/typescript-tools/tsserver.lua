local log = require "vim.lsp.log"
local TsserverProvider = require "typescript-tools.tsserver_provider"
local Process = require "typescript-tools.process"
local RequestQueue = require "typescript-tools.request_queue"
local handle_progress = require "typescript-tools.protocol.progress"
local module_mapper = require "typescript-tools.protocol.module_mapper"
local PendingDiagnostic = require "typescript-tools.protocol.pending_diagnostic"
local api = require "typescript-tools.api"
local c = require "typescript-tools.protocol.constants"
local proto_utils = require "typescript-tools.protocol.utils"

---@class Tsserver
---@field server_type "semantic"|"syntax"
---@field process Process
---@field request_queue RequestQueue
---@field pending_requests table<number|string, boolean|nil>
---@field requests_metadata RequestContainer[]
---@field requests_to_cancel_on_change table<number, table>
---@field pending_diagnostic PendingDiagnostic|nil
---@field dispatchers Dispatchers

---@class Tsserver
local Tsserver = {}

---@param type ServerType
---@param dispatchers Dispatchers
---@return Tsserver
function Tsserver.new(type, dispatchers)
  local self = setmetatable({}, { __index = Tsserver })

  self.server_type = type
  self.request_queue = RequestQueue.new()
  self.pending_requests = {}
  self.requests_metadata = {}
  self.requests_to_cancel_on_change = {}
  self.dispatchers = dispatchers

  TsserverProvider.init(function()
    self.process = Process.new(type, function(response)
      self:handle_response(response)
    end, dispatchers.on_exit)

    ---@diagnostic disable-next-line
    self:send_queued_requests()
  end)

  return self
end

---@private
---@param method LspMethods | CustomMethods
---@param data table
local function dispatch_update_event(method, data)
  if
    not (
      method == c.LspMethods.DidOpen
      or method == c.LspMethods.DidChange
      or method == c.LspMethods.DidClose
    )
  then
    return
  end

  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "TypescriptTools_" .. method,
      data = data,
    })
  end)
end

---@param response table
function Tsserver:handle_response(response)
  local seq = response.request_seq

  if self.pending_diagnostic and self.pending_diagnostic:handle_response(response) then
    self.pending_diagnostic = nil
    return
  end

  handle_progress(response, self.server_type, self.dispatchers)

  if not seq then
    return
  end

  local metadata = self.requests_metadata[seq]

  if not metadata then
    return
  end

  dispatch_update_event(metadata.method, response)

  local handler = metadata.handler

  coroutine.resume(handler, response.body or response, response.command or response.event)

  self.pending_requests[seq] = nil
  self.requests_metadata[seq] = nil
  self.requests_to_cancel_on_change[seq] = nil

  self:send_queued_requests()
end

---@param method LspMethods | CustomMethods
---@param params table|nil
---@param callback LspCallback
---@param notify_reply_callback function|nil
---@return boolean, number|nil
function Tsserver:handle_request(method, params, callback, notify_reply_callback)
  local _ = log.trace() and log.trace("tsserver", "Handling request: ", method)

  -- INFO: cancel request is special case, it need to be executed immediately
  if method == c.LspMethods.CancelRequest and params then
    self:cancel(params.id)
    return true
  end

  local module = module_mapper.map_method_to_module(method)

  -- INFO: skip sending request if it's a noop method
  if not module then
    return false
  end

  local ok, handler_module = pcall(require, "typescript-tools.protocol." .. module)

  if not ok or type(handler_module) ~= "table" then
    local _ = log.debug() and log.debug("tsserver", "Unimplemented method: ", method)
    local _ = log.debug() and log.debug("tsserver", "with params:", vim.inspect(params))
    return false
  end

  local handler = coroutine.create(handler_module.handler)

  local handler_context = {
    method = method,
    dependent_seq = {},
  }

  local function get_seq()
    return handler_context.dependent_seq[#handler_context.dependent_seq] or handler_context.seq
  end

  function handler_context.request(request)
    local interrupt_diagnostic = handler_module.interrupt_diagnostic

    self:cancel_on_change_requests(method, params)

    handler_context.seq = self.request_queue:enqueue {
      method = method,
      handler = handler,
      context = handler_context,
      request = request,
      priority = self.request_queue:get_queueing_type(method, handler_module.low_priority),
      interrupt_diagnostic = interrupt_diagnostic or type(interrupt_diagnostic) == "nil",
    }

    if handler_module.cancel_on_change and params then
      self.requests_to_cancel_on_change[handler_context.seq] = params.textDocument
        or (params.data or {}).textDocument
    end

    return handler_context.seq
  end

  function handler_context.response(response, error)
    local seq = get_seq()
    local notify_reply = notify_reply_callback and vim.schedule_wrap(notify_reply_callback)
    ---@type function|nil
    local response_callback = callback and vim.schedule_wrap(callback)

    -- INFO: to prevent multiple `on_attach` calls ignore `initialize` response from semantic
    -- server and respond only from syntax one
    if method == c.LspMethods.Initialize and self.server_type == "semantic" then
      notify_reply = nil
      response_callback = nil
    end

    if notify_reply then
      notify_reply(seq)
    end

    if response_callback then
      if error then
        response_callback(error, error)
      else
        response_callback(nil, response)
      end
    end
  end

  local _, err = coroutine.resume(
    handler,
    handler_context.request,
    handler_context.response,
    params,
    handler_context
  )

  local seq = get_seq()

  if err then
    local _ = log.error()
      and log.error("tsserver", "Unexpected error while handling request: ", handler_context.method)
    local _ = log.error() and log.error("tsserver", err)
    return false, seq
  end

  self:send_queued_requests()

  return true, seq
end

---@private
function Tsserver:send_queued_requests()
  if not self.process then
    return
  end

  while vim.tbl_isempty(self.pending_requests) and not self.request_queue:is_empty() do
    local item = self.request_queue:dequeue()
    if not item then
      local _ = log.debug() and log.debug("tsserver", "dequeued item is nil")
      return
    end

    local static_response = item.request.response
    if static_response then
      item.context.response(static_response)
    else
      local seq = item.context.seq

      if self.pending_diagnostic and item.interrupt_diagnostic then
        self:interrupt_diagnostic()
      end

      self.process:write(vim.tbl_extend("force", {
        seq = seq,
        type = "request",
      }, item.request))

      if item.method == c.CustomMethods.Diagnostic then
        self.pending_diagnostic = PendingDiagnostic.new(item)
      else
        self.pending_requests[seq] = true
        self.requests_metadata[seq] = item
      end
    end
  end
end

function Tsserver:interrupt_diagnostic()
  self.request_queue:cancel_diagnostics()
  self.process:cancel(self.pending_diagnostic:get_seq())
  self.pending_diagnostic = nil
  vim.schedule(function()
    api.request_diagnostics()
  end)
end

---@param seq number
function Tsserver:cancel(seq)
  local request_metadata = self.requests_metadata[seq] or self.request_queue:get_queued_request(seq)
  if not request_metadata then
    return
  end

  local seqs_to_cancel = request_metadata.context.dependent_seq or { request_metadata.context.seq }

  for _, iseq in ipairs(seqs_to_cancel) do
    if self.pending_requests[iseq] then
      self.process:cancel(iseq)
      self.requests_metadata[iseq].context.response(proto_utils.cancelled_response())
      self.requests_metadata[iseq] = nil
      self.pending_requests[iseq] = nil
    else
      local cancelled_req = self.request_queue:cancel(iseq)

      if cancelled_req then
        cancelled_req.context.response(proto_utils.cancelled_response())
      end
    end

    self.requests_to_cancel_on_change[iseq] = nil
  end
end

---@param method LspMethods
---@param params table|nil
function Tsserver:cancel_on_change_requests(method, params)
  if method ~= c.LspMethods.DidChange or not params then
    return
  end

  local uri = params.textDocument.uri

  for seq, text_document in pairs(self.requests_to_cancel_on_change) do
    if uri == text_document.uri then
      self:cancel(seq)
    end
  end
end

function Tsserver:terminate()
  self.process:terminate()
end

---@return boolean
function Tsserver:is_closing()
  return self.process:is_closing()
end

return Tsserver
