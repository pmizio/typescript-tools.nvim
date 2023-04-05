local uv = vim.loop
local Job = require "plenary.job"

local is_win = uv.os_uname().version:find "Windows"

--- @class Process
--- @field job table
--@field on_exit function
--@field stdin table
--@field stdout table
--@field stderr table
--@field spawn_args table
--@field handle table|nil
--@field cancellation_file string|nil

--- @class Process
local Process = {}

--- @param path table Plenary path object
--- @return Process
function Process:new(path)
  local obj = {}

  local command = is_win and "cmd.exe" or "node"
  local args = {
    path:absolute(),
    "--stdio",
    "--local",
    "en",
    "--useInferredProjectPerProjectRoot",
    "--validateDefaultNpmLocation",
    "--noGetErrOnBackgroundUpdate",
  }

  if is_win then
    table.insert(args, 2, "node")
    table.insert(args, 2, "/C")
  end

  obj.job = Job:new {
    command = command,
    args = args,
    on_stdout = function(_, data)
      if data == "" then
        return
      end

      P(data)
    end,
  }
  obj.job:start()

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function Process:send(x)
  self.job:send(x)
  -- INFO: flush message
  self.job:send "\r\n"
end

return Process
