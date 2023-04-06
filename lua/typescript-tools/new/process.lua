local uv = vim.loop
local log = require "vim.lsp.log"
local Job = require "plenary.job"

local HEADER = "Content-Length: "

local is_win = uv.os_uname().version:find "Windows"

---@class Process
---@field job table

---@class Process
local Process = {}

---@param path table Plenary path object
---@param on_response fun(response: table)
---@return Process
function Process:new(path, on_response)
  local obj = {}

  local command = is_win and "cmd.exe" or "node"

  -- stylua: ignore start
  local args = {
    path:absolute(),
    "--stdio",
    "--local", "en",
    "--useInferredProjectPerProjectRoot",
    "--validateDefaultNpmLocation",
    "--noGetErrOnBackgroundUpdate",
  }
  -- stylua: ignore end

  if is_win then
    table.insert(args, 2, "node")
    table.insert(args, 2, "/C")
  end

  ---@param _ string
  local parse_response = coroutine.wrap(function(_)
    while true do
      ---@type string
      local data = coroutine.yield()

      if not data:find(HEADER, 1, true) then
        goto continue
      end

      local length = tonumber(data:sub(#HEADER + 1)) - 1
      data = coroutine.yield()

      if #data == length then
        ---@diagnostic disable-next-line
        local ok, response = pcall(vim.json.decode, data, { luanil = { object = true } })
        if not ok then
          log.error("Invalid json: ", response)
          return
        end

        ---@diagnostic disable-next-line
        on_response(response)
      end

      ::continue::
    end
  end)
  -- INFO: skip first call and proceed to first yield
  parse_response()

  obj.job = Job:new {
    command = command,
    args = args,
    on_stdout = function(_, data)
      if data == "" then
        return
      end

      parse_response(data)
    end,
  }
  obj.job:start()

  setmetatable(obj, self)
  self.__index = self

  return obj
end

---@param request table
function Process:send(request)
  self.job:send(vim.json.encode(request))
  -- INFO: flush message
  self.job:send "\r\n"
end

return Process
