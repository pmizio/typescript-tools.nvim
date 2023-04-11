local log = require "vim.lsp.log"
local Process = require "typescript-tools.new.process"
local RequestQueue = require "typescript-tools.new.request_queue"
local handle_progress = require "typescript-tools.new.protocol.progress"
local module_mapper = require "typescript-tools.new.protocol.module_mapper"
local c = require "typescript-tools.protocol.constants"

---@class PendingRequest
---@field method LspMethods | CustomMethods
---@field handler thread|false|nil
---@field callback LspCallback|nil
---@field notify_reply_callback function|nil
---@field cancelled boolean|nil

---@class Tsserver
---@field process Process
---@field request_queue RequestQueue
---@field pending_requests PendingRequest[]
---@field pending_diagnostic_seq number
---@field dispatchers Dispatchers

---@class Tsserver
local Tsserver = {}

---@param path table Plenary path object
---@param dispatchers Dispatchers
---@return Tsserver
function Tsserver:new(path, dispatchers)
  local obj = {
    request_queue = RequestQueue:new(),
    pending_requests = {},
    dispatchers = dispatchers,
  }

  setmetatable(obj, self)
  self.__index = self

  obj.process = Process:new(path, function(response)
    obj:handle_response(response)
    obj:send_queued_requests()
  end, dispatchers.on_exit)

  return obj
end

---@param response table
function Tsserver:handle_response(response)
  local seq = response.request_seq
  local is_diagnostic_event = self:is_diagnostic_event(response)

  -- INFO: seq in requestCompleted tsserver command
  if not seq and type(response.body) == "table" then
    seq = response.body.request_seq
  end

  -- INFO: seq for diagnostic events
  if not seq and is_diagnostic_event then
    seq = self.pending_diagnostic_seq
  end

  local request_metadata = self.pending_requests[seq]

  handle_progress(response, self.dispatchers)

  if not seq or not request_metadata then
    return
  end

  if response.event == c.DiagnosticEventKind.RequestCompleted then
    self.pending_diagnostic_seq = nil
  end

  if request_metadata.cancelled then
    self.pending_requests[seq] = nil
    return
  end

  self:dispatch_update_event(request_metadata.method, response)

  local handler = request_metadata.handler
  local callback = request_metadata.callback
  local notify_reply_callback = request_metadata.notify_reply_callback

  local ok, handler_success, result =
    pcall(coroutine.resume, handler, response.body or response, response.command or response.event)

  if is_diagnostic_event then
    return
  end

  self.pending_requests[seq] = nil

  vim.schedule(function()
    if not ok then
      -- INFO: request don't have equvalent in lsp - just skip response
      return
    end

    if notify_reply_callback then
      notify_reply_callback(seq)
    end

    if callback then
      if handler_success then
        callback(nil, result)
      else
        callback(result, result)
      end
    end
  end)
end

---@param method LspMethods | CustomMethods
---@param params table|nil
---@param callback LspCallback
---@param notify_reply_callback function|nil
function Tsserver:handle_request(method, params, callback, notify_reply_callback)
  local module = module_mapper.map_method_to_module(method)

  print(method, module)

  local ok, request_creator = pcall(require, "typescript-tools.new.protocol." .. module)
  if not ok then
    -- TODO: log message
    P(handler)
    return
  end

  ---@type TsserverRequest | TsserverRequest[], function | nil
  local requests, handler_fn = request_creator(method, params)

  ---@param request table
  ---@return number
  local function enqueue_request(request)
    local copy = vim.tbl_extend("force", {}, request)
    copy.skip_response = nil

    return self.request_queue:enqueue {
      method = method,
      handler = not request.skip_response and handler_fn,
      request = copy,
      callback = callback,
      notify_reply_callback = notify_reply_callback,
      priority = self.request_queue:get_queueing_type(method),
    }
  end

  local pending_diagnostic = self.pending_requests[self.pending_diagnostic_seq]
  if pending_diagnostic then
    self.request_queue:clear_diagnostics()
    pending_diagnostic.cancelled = true
    self.process:cancel(self.pending_diagnostic_seq)
  end

  local seq
  if vim.tbl_islist(requests) then
    for _, request in ipairs(requests) do
      seq = enqueue_request(request)
    end
  else
    seq = enqueue_request(requests)
  end

  self:send_queued_requests()

  return seq
end

---@private
function Tsserver:send_queued_requests()
  while vim.tbl_isempty(self.pending_requests) and not self.request_queue:is_empty() do
    local item = self.request_queue:dequeue()
    if not item then
      return
    end

    local request = vim.tbl_extend("force", {
      seq = item.seq,
      type = "request",
    }, item.request)

    self.process:send(request)

    if item.method == c.CustomMethods.BatchDiagnostics then
      self.pending_diagnostic_seq = request.seq
    end

    self.pending_requests[request.seq] = {
      method = item.method,
      handler = item.handler and coroutine.create(item.handler),
      callback = item.callback,
      notify_reply_callback = item.notify_reply_callback,
    }
  end
end

---@private
---@param method LspMethods | CustomMethods
---@param data table
function Tsserver:dispatch_update_event(method, data)
  if not (method == c.LspMethods.DidOpen or method == c.LspMethods.DidChange) then
    return
  end

  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "TypescriptTools_" .. method,
      data = data,
    })
  end)
end

---@private
---@param response table
---@return boolean
function Tsserver:is_diagnostic_event(response)
  if response.type ~= "event" then
    return false
  end

  local event = response.event

  return event == c.DiagnosticEventKind.SyntaxDiag
    or event == c.DiagnosticEventKind.SemanticDiag
    or event == c.DiagnosticEventKind.SuggestionDiag
end

function Tsserver:terminate()
  self.process:terminate()
end

---@return boolean
function Tsserver:is_closing()
  return self.process:is_closing()
end

return Tsserver
