local uv = vim.loop
local log = require "vim.lsp.log"

local HEADER = "Content-Length: "

local is_win = uv.os_uname().version:find "Windows"

---@class Process
---@field private handle uv.uv_handle_t|uv.uv_process_t|nil
---@field private stdin uv.uv_pipe_t
---@field private stdout uv.uv_pipe_t
---@field private stderr uv.uv_pipe_t
---@field private args string[]
---@field private on_response fun(response: table)
---@field private on_exit fun(code: number, signal: number)

---@class Process
local Process = {}

---@param path table Plenary path object
---@param on_response fun(response: table)
---@param on_exit fun(code: number, signal: number)
---@return Process
function Process:new(path, on_response, on_exit)
    -- stylua: ignore start
  local obj = {
    handle = nil,
    stdin = uv.new_pipe(false),
    stdout = uv.new_pipe(false),
    stderr = uv.new_pipe(false),
    args = {
      path:absolute(),
      "--stdio",
      "--local", "en",
      "--useInferredProjectPerProjectRoot",
      "--validateDefaultNpmLocation",
      "--noGetErrOnBackgroundUpdate",
    },
    on_response=on_response,
    on_exit=on_exit
  }
  -- stylua: ignore end

  if is_win then
    table.insert(obj.args, 2, "node")
    table.insert(obj.args, 2, "/C")
  end

  setmetatable(obj, self)
  self.__index = self

  obj:start()

  return obj
end

---@param header_string string
---@return number
local function parse_content_length(header_string)
  return tonumber(header_string:sub(#HEADER + 1)) - 1
end

---@param initial_chunk string
---@param on_response fun(response: table)
local parse_response = function(initial_chunk, on_response)
  local buffer = initial_chunk or ""

  while true do
    local header_end, body_start = buffer:find("\r\n\r\n", 1, true)

    if header_end then
      local header = buffer:sub(1, header_end - 1)
      local content_length = parse_content_length(header)
      local body = buffer:sub(body_start + 1)
      local body_chunks = { body }
      local body_length = #body

      while body_length < content_length do
        local chunk = coroutine.yield()
        table.insert(body_chunks, chunk)
        body_length = body_length + #chunk
      end

      local chunks = table.concat(body_chunks, "")
      body = chunks:sub(1, content_length)
      buffer = chunks:sub(content_length + 1)

      local ok, response = pcall(vim.json.decode, body, { luanil = { object = true } })
      if not ok or not response then
        log.error("Invalid json: ", response)
        return
      end

      on_response(response)
    else
      buffer = buffer .. coroutine.yield()
    end
  end
end

function Process:start()
  local command = is_win and "cmd.exe" or "node"
  local args = {
    args = self.args,
    stdio = { self.stdin, self.stdout, self.stderr },
    detached = not is_win,
  }

  local handle, pid = uv.spawn(command, args, function(...)
    self:close_pipes()
    self.handle:close()
    self.on_exit(...)
  end)

  ---@diagnostic disable-next-line
  self.handle = handle

  if handle == nil then
    self:close_pipes()

    local msg = "Spawning language server with cmd: `tsserver` failed"
    if string.match(tostring(pid), "ENOENT") then
      msg = msg
        .. ". The language server is either not installed, missing from PATH, or not executable."
    else
      msg = msg .. string.format(" with error message: %s", pid)
    end

    vim.notify(msg, vim.log.levels.WARN)
  end

  local parse_response_coroutine = coroutine.wrap(parse_response)

  self.stdout:read_start(function(err, chunk)
    if err then
      -- TODO: any error handling
      print "error on stdout"
      return
    end

    -- INFO: just skip empty chunks
    if not chunk then
      return
    end

    parse_response_coroutine(chunk, self.on_response)
  end)

  self.stderr:read_start(function(_, chunk)
    if chunk then
      local _ = log.error() and log.error("rpc", "tsserver", "stderr", chunk)
    end
  end)
end

---@private
function Process:close_pipes()
  self.stdin:close()
  self.stdout:close()
  self.stderr:close()
end

---@param request table
function Process:send(request)
  local serialized_request = vim.json.encode(request)
  if not serialized_request then
    -- TODO: propper error log here
    return
  end

  self.stdin:write(serialized_request)
  -- INFO: flush message
  self.stdin:write "\r\n"
end

function Process:terminate()
  if self.handle then
    self.handle:kill(15)
  end
end

---@return boolean
function Process:is_closing()
  return self.handle == nil or (not not self.handle:is_closing())
end

return Process
