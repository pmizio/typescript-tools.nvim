local c = require "typescript-tools.protocol.constants"

local CONST_QUEUE_REQUESTS = {
  c.LspMethods.DidOpen,
  c.LspMethods.DidChange,
  c.LspMethods.DidClose,
}

---@class RequestContainer
---@field method LspMethods | CustomMethods
---@field handler thread
---@field context TsserverHandlerContext
---@field request TsserverRequest
---@field priority Priority
---@field interrupt_diagnostic boolean|nil

---@class RequestQueue
---@field seq number
---@field queue RequestContainer[]

---@class RequestQueue
local RequestQueue = {
  ---@enum Priority
  Priority = {
    Low = 1,
    Normal = 2,
    Const = 3,
  },
  seq = 0,
}

---@return RequestQueue
function RequestQueue.new()
  local self = setmetatable({}, { __index = RequestQueue })

  self.queue = {}

  return self
end

---@param request RequestContainer
function RequestQueue:enqueue(request)
  local seq = RequestQueue.seq

  if request.priority == self.Priority.Normal then
    local idx = #self.queue

    for i = #self.queue, 1, -1 do
      idx = i

      if self.queue[i].priority ~= self.Priority.Low then
        break
      end
    end

    table.insert(self.queue, idx + 1, request)
  else
    table.insert(self.queue, request)
  end

  RequestQueue.seq = seq + 1

  return seq
end

---@return RequestContainer
function RequestQueue:dequeue()
  local request = self.queue[1]
  table.remove(self.queue, 1)

  return request
end

function RequestQueue:cancel_diagnostics()
  for i = #self.queue, 1, -1 do
    local el = self.queue[i]

    if el.method == c.CustomMethods.Diagnostic then
      table.remove(self.queue, i)
    end
  end
end

---@param seq number
---@return RequestContainer|nil
function RequestQueue:cancel(seq)
  for i = #self.queue, 1, -1 do
    local el = self.queue[i]

    if el.context.seq == seq then
      table.remove(self.queue, i)
      return el
    end
  end
end

---@param seq number
---@return RequestContainer|nil
function RequestQueue:get_queued_request(seq)
  for _, el in ipairs(self.queue) do
    if seq and el.context.seq == seq then
      return el
    end
  end

  return nil
end

---@return boolean
function RequestQueue:is_empty()
  return #self.queue == 0
end

---@param method LspMethods
---@param is_low_priority string|nil
---@return Priority
function RequestQueue:get_queueing_type(method, is_low_priority)
  if vim.tbl_contains(CONST_QUEUE_REQUESTS, method) then
    return self.Priority.Const
  end

  return is_low_priority and self.Priority.Low or self.Priority.Normal
end

return RequestQueue
