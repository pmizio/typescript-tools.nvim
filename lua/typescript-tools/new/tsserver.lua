local log = require "vim.lsp.log"
local Process = require "typescript-tools.new.process"
local RequestQueue = require "typescript-tools.request_queue"
local handle_progress = require "typescript-tools.new.protocol.progress"
local comm = require "typescript-tools.new.communication"
local c = require "typescript-tools.protocol.constants"

---@class Tsserver
---@field process Process
---@field request_queue RequestQueue
---@field pending_requests table
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
  end)

  return obj
end

---@param response table
function Tsserver:handle_response(response)
  local seq = response.request_seq
  local request_metadata = self.pending_requests[seq]
  -- P(response)
  -- P(self.pending_requests)

  handle_progress(response, self.dispatchers)

  if not request_metadata then
    return
  end

  local handler = request_metadata.handler
  local callback = request_metadata.callback
  local notify_reply_callback = request_metadata.notify_reply_callback

  local ok, handler_success, result = pcall(coroutine.resume, handler, response)
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

---@param method string
---@param params table|nil
---@param callback LspCallback
---@param notify_reply_callback function|nil
function Tsserver:handle_request(method, params, callback, notify_reply_callback)
  local module = method:gsub("%$/", ""):gsub("/", "."):gsub("%u", function(c)
    return "_" .. c:lower()
  end)

  if method == c.LspMethods.CompletionResolve then
    module = "text_document.completion.resolve"
  end

  print(method, module)
  local ok, handler = pcall(require, "typescript-tools.new.protocol." .. module)
  if not ok then
    -- TODO: log message
    P(handler)
    return
  end

  local co = handler(method, params)
  local seq
  repeat
    local _, request, request_type = coroutine.resume(co)
    seq = self.request_queue:enqueue {
      handler = request_type ~= comm.RequestType.SKIP and co or nil,
      request = request,
      callback = callback,
      notify_reply_callback = notify_reply_callback,
      priority = RequestQueue.Priority.Normal,
    }
  until request_type == comm.RequestType.AWAIT or coroutine.status(co) == "dead"

  self:send_queued_requests()

  return seq
end

---@private
function Tsserver:send_queued_requests()
  while vim.tbl_isempty(self.pending_requests) and self.request_queue:is_empty() do
    local item = self.request_queue:dequeue()
    if not item then
      return
    end

    local request = vim.tbl_extend("force", {
      seq = item.seq,
      type = "request",
    }, item.request)

    self.process:send(request)

    self.pending_requests[request.seq] = {
      handler = item.handler,
      callback = item.callback,
      notify_reply_callback = item.notify_reply_callback,
    }
  end
end

return Tsserver
