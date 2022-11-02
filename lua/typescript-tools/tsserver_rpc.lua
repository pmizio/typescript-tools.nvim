local uv = vim.loop
local log = require "vim.lsp.log"
local Path = require "plenary.path"
local config = require "typescript-tools.config"

local is_win = uv.os_uname().version:find "Windows"

local CANCELLATION_PREFIX = "seq_"

---@class TsserverRpc
---@field on_exit function
---@field stdin table
---@field stdout table
---@field stderr table
---@field spawn_args table
---@field handle table|nil
---@field cancellation_file string|nil

---@class TsserverRpc
local TsserverRpc = {}

--- @param path table Plenary path object
--- @param server_type string
--- @return table
function TsserverRpc:new(path, server_type, on_exit)
  local obj = {
    on_exit = on_exit,
    stdin = uv.new_pipe(false),
    stdout = uv.new_pipe(false),
    stderr = uv.new_pipe(false),
    handle = nil,
  }

  setmetatable(obj, self)
  self.__index = self

  local tsserver_bin = path:absolute()
  local cmd = { tsserver_bin }

  if is_win then
    cmd = { "cmd.exe", "/C", "node", tsserver_bin }
  end

  obj.spawn_args = {
    args = cmd,
    stdio = { obj.stdin, obj.stdout, obj.stderr },
    detached = not is_win,
  }

  obj:add_spawn_arg "--stdio"
  obj:add_spawn_arg("--locale", "en")
  obj:add_spawn_arg "--useInferredProjectPerProjectRoot"
  obj:add_spawn_arg "--validateDefaultNpmLocation"
  obj:add_spawn_arg "--noGetErrOnBackgroundUpdate"

  local cancellation_dir = uv.fs_mkdtemp(uv.os_tmpdir() .. "/tsserver_nvim_XXXXXX")

  if cancellation_dir then
    obj.cancellation_file = Path:new(cancellation_dir, CANCELLATION_PREFIX):absolute()

    obj:add_spawn_arg("--cancellationPipeName", obj.cancellation_file .. "*")
  end

  local logs = config.tsserver_logs

  if logs then
    obj:add_spawn_arg("--logVerbosity", logs.verbosity)
    obj:add_spawn_arg("--logFile", logs.file_basename .. server_type .. ".log")
  end

  return obj
end

--- @param arg string
--- @param value string|nil
function TsserverRpc:add_spawn_arg(arg, value)
  table.insert(self.spawn_args.args, arg)

  if value ~= nil then
    table.insert(self.spawn_args.args, value)
  end
end

--- @return boolean
function TsserverRpc:spawn()
  local handle, pid = uv.spawn("node", self.spawn_args, function(code, signal)
    self:close_pipes()

    if self.on_exit then
      self.on_exit(code, signal)
    end
  end)
  self.handle = handle

  if handle == nil then
    self:close_pipes()

    local msg = "Spawning language server with cmd: `tsserver` failed"
    if string.match(pid, "ENOENT") then
      msg = msg
        .. ". The language server is either not installed, missing from PATH, or not executable."
    else
      msg = msg .. string.format(" with error message: %s", pid)
    end

    vim.notify(msg, vim.log.levels.WARN)

    return false
  end

  return true
end

--- @private
--- tsserver send only one header - Content-Length so we can just hardcode length of header name:
--- Content-Length:_ = 16, but lua is 1 based so: 16 + 1 = 17
---
--- @param header_string string
--- @return number
function TsserverRpc:parse_content_length(header_string)
  return tonumber(header_string:sub(17))
end

--- @param callback function
--- @return nil
function TsserverRpc:on_message(callback)
  --- @param initial_chunk string
  --- @return nil
  local parse_response = coroutine.wrap(function(initial_chunk)
    local buffer = initial_chunk or ""

    while true do
      local header_end, body_start = buffer:find("\r\n\r\n", 1, true)

      if header_end then
        local header = buffer:sub(1, header_end - 1)
        local content_length = self:parse_content_length(header)
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

        callback(body)
      else
        buffer = buffer .. coroutine.yield()
      end
    end
  end)

  self.stdout:read_start(function(err, chunk)
    if err then
      -- TODO: any error handling
      P "error on stdout"
      return
    end

    -- just skip empty chunks
    if not chunk then
      return
    end

    parse_response(chunk)
  end)

  self.stderr:read_start(function(_, chunk)
    if chunk then
      local _ = log.error() and log.error("rpc", "tsserver", "stderr", chunk)
    end
  end)
end

--- @param message table
--- @return nil
function TsserverRpc:write(message)
  self.stdin:write(vim.json.encode(message))
  -- this flush request to tsserver
  self.stdin:write "\r\n"
end

--- @param seq number
function TsserverRpc:cancel(seq)
  assert(self.cancellation_file, "Cancellation pipe wasn't created, cannot cancel request!")

  Path:new(self.cancellation_file .. seq):touch { mode = 438 }
end

--- @return boolean
function TsserverRpc:is_closing()
  return self.handle == nil or self.handle:is_closing()
end

--- @return nil
function TsserverRpc:terminate()
  if self.handle then
    self.handle:kill(15)
  end
end

--- @private
--- @return nil
function TsserverRpc:close_pipes()
  self.stdin:close()
  self.stdout:close()
  self.stderr:close()
end

return TsserverRpc
