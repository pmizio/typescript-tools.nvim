local uv = vim.loop
local log = require "vim.lsp.log"
local Path = require "plenary.path"
local plugin_config = require "typescript-tools.config"
local TsserverProvider = require "typescript-tools.tsserver_provider"

local HEADER = "Content-Length: "
local CANCELLATION_PREFIX = "seq_"

local is_win = uv.os_uname().version:find "Windows"

---@class Process
---@field private handle uv.uv_handle_t|uv.uv_process_t|nil
---@field private stdin uv.uv_pipe_t
---@field private stdout uv.uv_pipe_t
---@field private stderr uv.uv_pipe_t
---@field private args string[]
---@field private cancellation_dir Path
---@field private on_response fun(response: table)
---@field private on_exit fun(code: number, signal: number)

---@class Process
local Process = {}

---@param type ServerType
---@param on_response fun(response: table)
---@param on_exit fun(code: number, signal: number)
---@return Process
function Process.new(type, on_response, on_exit)
  local self = setmetatable({}, { __index = Process })

  local tsserver_provider = TsserverProvider.get_instance()

  self.handle = nil
  self.stdin = uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)
  self.cancellation_dir =
    Path:new(uv.fs_mkdtemp(Path:new(uv.os_tmpdir(), "tsserver_nvim_XXXXXX"):absolute()))
    -- stylua: ignore start
    self.args = {
      tsserver_provider:get_executable_path():absolute(),
      "--stdio",
      "--locale", plugin_config.tsserver_locale,
      "--useInferredProjectPerProjectRoot",
      "--validateDefaultNpmLocation",
      "--noGetErrOnBackgroundUpdate",
      "--cancellationPipeName",
      self.cancellation_dir:joinpath(CANCELLATION_PREFIX .. "*"):absolute(),
    }
  -- stylua: ignore end
  self.on_response = on_response
  self.on_exit = on_exit

  local plugins_path = tsserver_provider:get_plugins_path()

  if plugins_path and #plugin_config.tsserver_plugins > 0 then
    table.insert(self.args, "--pluginProbeLocations")
    table.insert(self.args, plugins_path:absolute())
    table.insert(self.args, "--globalPlugins")
    table.insert(self.args, table.concat(plugin_config.tsserver_plugins, ","))
  end

  if plugin_config.tsserver_logs ~= "off" then
    local log_dir = Path:new(uv.os_tmpdir())
    table.insert(self.args, "--logVerbosity")
    table.insert(self.args, plugin_config.tsserver_logs)
    table.insert(self.args, "--logFile")
    table.insert(self.args, log_dir:joinpath("tsserver_" .. type .. ".log"):absolute())
  end

  self:start()

  return self
end

---@param header_string string
---@return number
local function parse_content_length(header_string)
  return tonumber(header_string:sub(#HEADER + 1)) - 1
end

---@param initial_chunk string
---@param on_response fun(response: table)
local function parse_response(initial_chunk, on_response)
  local buffer = initial_chunk or ""

  while true do
    local header_end, body_start = buffer:find("\r\n\r\n", 1, true)

    if header_end then
      local header = buffer:sub(1, header_end - 1)
      -- INFO: on Windows there is additional whitespace before header we need to remove them
      if header:sub(1, 2) == "\r\n" then
        header = header:sub(3)
      end
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
        local _ = log.error() and log.error("tsserver", "Invalid json: ", response)
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

  if type(plugin_config.tsserver_max_memory) == "number" then
    table.insert(self.args, 1, "--max-old-space-size=" .. plugin_config.tsserver_max_memory)
  end

  if is_win then
    table.insert(self.args, 1, "/c")
    table.insert(self.args, 2, "node")
  end

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
      local _ = log.error() and log.error("tsserver", "Read from stdout returned error: ", err)
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
      local _ = log.error() and log.error() and log.error("process", "tsserver", "stderr", chunk)
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
function Process:write(request)
  local serialized_request = vim.json.encode(request)
  if not serialized_request then
    local _ = log.error() and log.error("tsserver", "Failed to encode request: ", request)
    return
  end

  self.stdin:write(serialized_request)
  -- INFO: flush message
  self.stdin:write "\r\n"
end

---@param seq number
function Process:cancel(seq)
  assert(self.cancellation_dir:exists(), "Cancellation pipe wasn't created, cannot cancel request!")

  self.cancellation_dir:joinpath(CANCELLATION_PREFIX .. seq):touch { mode = 438 }
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
