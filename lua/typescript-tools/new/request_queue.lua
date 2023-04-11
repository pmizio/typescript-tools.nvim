local c = require "typescript-tools.protocol.constants"

local CONST_QUEUE_REQUESTS = {
  c.LspMethods.DidOpen,
  c.LspMethods.DidChange,
  c.LspMethods.DidClose,
}

---@class RequestContainer
---@field seq number
---@field priority number
---@field method LspMethods | CustomMethods
---@field handler function|false|nil
---@field callback LspCallback
---@field notify_reply_callback function|nil

---@class RequestQueue
---@field seq number
---@field queue RequestContainer[]

---@class RequestQueue
local RequestQueue = {
  Priority = {
    Low = 1,
    Normal = 2,
    Const = 3,
  },
}

---@return RequestQueue
function RequestQueue:new()
  local obj = {
    seq = 0,
    queue = {},
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

---@param request RequestContainer
function RequestQueue:enqueue(request)
  local seq = self.seq

  request.seq = seq

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

  self.seq = seq + 1

  return seq
end

---@return RequestContainer
function RequestQueue:dequeue()
  local request = self.queue[1]
  table.remove(self.queue, 1)

  return request
end

function RequestQueue:clear_diagnostics()
  for i = #self.queue, 1, -1 do
    local el = self.queue[i]

    if el.method == c.CustomMethods.BatchDiagnostics then
      table.remove(self.queue, i)
    end
  end
end

---@return boolean
function RequestQueue:is_empty()
  return #self.queue == 0
end

--@param method LspMethods
--@param is_low_priority string|nil
--@return number
function RequestQueue:get_queueing_type(method, is_low_priority)
  if vim.tbl_contains(CONST_QUEUE_REQUESTS, method) then
    return self.Priority.Const
  end

  return is_low_priority and self.Priority.Low or self.Priority.Normal
end

return RequestQueue
