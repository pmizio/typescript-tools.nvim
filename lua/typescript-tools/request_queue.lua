local constants = require "typescript-tools.protocol.constants"

local CONST_QUEUE_REQUESTS = {
  constants.CommandTypes.Open,
  constants.CommandTypes.Change,
  constants.CommandTypes.Close,
  constants.CommandTypes.UpdateOpen,
}

--- @class RequestQueue
--- @field seq number
--- @field queue table

--- @class RequestQueue
local RequestQueue = {
  Priority = {
    Low = 1,
    Normal = 2,
    Const = 3,
  },
}

--- @return RequestQueue
function RequestQueue:new()
  local obj = {
    seq = 0,
    queue = {},
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @param message table
function RequestQueue:enqueue(message)
  local seq = self.seq

  message.seq = seq

  if message.priority == self.Priority.Normal then
    local idx = #self.queue

    for i = #self.queue, 1, -1 do
      if self.queue[i].priority ~= self.Priority.Low then
        idx = 1
        break
      end
    end

    table.insert(self.queue, idx + 1, message)
  else
    table.insert(self.queue, message)
  end

  self.seq = seq + 1

  return seq
end

--- @return table
function RequestQueue:dequeue()
  local message = self.queue[1]
  table.remove(self.queue, 1)

  return message
end

function RequestQueue:clear_geterrs()
  for i = #self.queue, 1, -1 do
    local el = self.queue[i]

    if el.message.command == constants.CommandTypes.Geterr and el.params.cancellable then
      table.remove(self.queue, i)
    end
  end
end

--- @return boolean
function RequestQueue:is_empty()
  return #self.queue > 0
end

--- @param command string
--- @param is_low_priority string|nil
--- @return number
function RequestQueue:get_queueing_type(command, is_low_priority)
  if vim.tbl_contains(CONST_QUEUE_REQUESTS, command) then
    return self.Priority.Const
  end

  return is_low_priority and self.Priority.Low or self.Priority.Normal
end

--- @param command string
--- @return boolean
function RequestQueue:has_command_queued(command)
  for i = #self.queue, 1, -1 do
    if self.queue[i].message.command == command then
      return true
    end
  end

  return false
end

return RequestQueue
