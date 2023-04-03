local api = vim.api
local schedule_wrap = vim.schedule_wrap

local log = require "vim.lsp.log"
local constants = require "typescript-tools.protocol.constants"
local config = require "typescript-tools.config"
local TsserverRpc = require "typescript-tools.tsserver_rpc"
local RequestQueue = require "typescript-tools.request_queue"
local global_initialize = require "typescript-tools.protocol.handlers.initialize"
local file_initialize = require "typescript-tools.protocol.handlers.did_open"
local request_handlers = require("typescript-tools.protocol").request_handlers
local response_handlers = require("typescript-tools.protocol").response_handlers
local ProjectLoadService = require "typescript-tools.protocol.project_load"
local CodeActionsService = require "typescript-tools.protocol.code_actions"
local custom_handlers = require "typescript-tools.custom_handlers"
local autocommands = require "typescript-tools.autocommands"

--- @class TsserverInstance
--- @field rpc TsserverRpc
--- @field server_type string
--- @field request_queue RequestQueue
--- @field pending_responses table
--- @field request_metadata table
--- @field project_load_service ProjectLoadService
--- @field code_actions_service CodeActionsService

--- @class TsserverInstance
local TsserverInstance = {}

--- @param path table Plenary path object
--- @param server_type string
--- @param dispatchers table
--- @return TsserverInstance
function TsserverInstance:new(path, server_type, dispatchers)
  local obj = {
    server_type = server_type,
    request_queue = RequestQueue:new(),
    pending_responses = {},
    request_metadata = {},
  }

  obj.rpc = TsserverRpc:new(path, server_type, function(...)
    obj:on_exit()
    dispatchers.on_exit(...)
  end)
  obj.project_load_service = ProjectLoadService:new(dispatchers)
  obj.code_actions_service = CodeActionsService:new(server_type, obj)

  setmetatable(obj, self)
  self.__index = self

  if obj.rpc:spawn() then
    obj.rpc:on_message(function(message)
      obj:handle_response(message)
    end)
  end

  custom_handlers.setup_lsp_handlers(dispatchers)
  autocommands.setup_autocmds(obj)

  return obj
end

function TsserverInstance:on_exit()
  self.project_load_service:dispose()
end

function TsserverInstance:invoke_response_handler(handler, command, response, request_seq)
  local request_data = self.request_metadata[request_seq]
  local request_params = request_data.params
  local callback = request_data.callback
  local notify_reply_callback = request_data.notify_reply_callback

  -- INFO: tsserver diagonstics request completed events don't have success field
  if response.success or command == constants.RequestCompletedEventName then
    local status, result = pcall(handler, command, response.body or response, request_params)

    if notify_reply_callback then
      notify_reply_callback(request_seq)
    end

    if callback then
      if status then
        callback(nil, result)
      else
        callback(result, result)
      end
    end
    -- INFO: exclude SignatureHelp fail response for compatibility with `lsp_signature.nvim`
    -- this plugin ask for signature even outisde function brakets so error reporst are annoying
    -- maybe this plugin can implement this feautre in future using treesitter to reduce
    -- request/respunse ping-pong
    -- INFO: exclude CompletionInfo fail response because it fail always in comments
    -- probably I can do it better detecting comments using treesitter but it is ok for now
  elseif
    not response.success
    and response.command ~= constants.CommandTypes.SignatureHelp
    and response.command ~= constants.CommandTypes.CompletionInfo
  then
    vim.schedule(function()
      vim.notify(response.message or "No information available.", log.levels.INFO)
    end)
  end

  self.pending_responses[request_seq] = nil
  self.request_metadata[request_seq] = nil
end

--- @private
--- @param message string
function TsserverInstance:handle_response(message)
  local ok, response = pcall(vim.json.decode, message, { luanil = { object = true } })
  if not ok or not response then
    log.error("Invalid json: ", response)
    return
  end

  local command = response.event or response.command
  local request_seq = (type(response.body) == "table" and response.body.request_seq)
      and response.body.request_seq
    or response.request_seq
  local handler_config = response_handlers[command]
  local request_data = self.request_metadata[request_seq]

  vim.schedule(function()
    api.nvim_exec_autocmds("User", {
      pattern = "tsserver_response_" .. command,
      data = request_data and request_data.message,
      modeline = false,
    })
  end)

  if handler_config then
    -- INFO: tsserver diagonstics events don't have seq number
    if not request_seq and response.type == "event" then
      local _, err = pcall(handler_config.handler, command, response.body or response)
      if not err then
        log.error("Diagnostics conversion error: ", err)
      end
    end

    if self.pending_responses[request_seq] then
      if handler_config.schedule then
        vim.schedule(function()
          self:invoke_response_handler(handler_config.handler, command, response, request_seq)
        end)
      else
        self:invoke_response_handler(handler_config.handler, command, response, request_seq)
      end
    end
  end

  if not handler_config and self.pending_responses[request_seq] then
    self.pending_responses[request_seq] = nil
  end

  if not handler_config and self.request_metadata[request_seq] then
    self.request_metadata[request_seq] = nil
  end

  self.project_load_service:handle_event(response)
  self.code_actions_service:handle_response(response)

  self:send_queued_requests()
end

--- @private
--- @param method string
--- @param params table
--- @param callback function
--- @param notify_reply_callback function
--- @param is_async boolean|nil
function TsserverInstance:handle_request(method, params, callback, notify_reply_callback, is_async)
  local seq = nil
  local tsserver_request_config = request_handlers[method]

  if tsserver_request_config then
    local tsserver_request = tsserver_request_config.handler
    local scheduled_callback = callback and schedule_wrap(callback) or nil
    local scheduled_notify_reply_callback = notify_reply_callback
        and schedule_wrap(notify_reply_callback)
      or nil
    local message =
      tsserver_request(method, params, scheduled_callback, scheduled_notify_reply_callback)

    local args = {
      message = message,
      params = params,
      callback = scheduled_callback,
      notify_reply_callback = scheduled_notify_reply_callback,
      is_async = is_async,
      priority = self.request_queue:get_queueing_type(message.command, params.low_priority),
    }

    seq = self.request_queue:enqueue(args)
  elseif method == constants.LspMethods.CodeAction then
    seq = self.code_actions_service:request(params, callback, notify_reply_callback)
  end

  self:send_queued_requests()

  if seq ~= nil then
    return true, seq
  end

  return nil
end

function TsserverInstance:send_queued_requests()
  while vim.tbl_isempty(self.pending_responses) and self.request_queue:is_empty() do
    local item = self.request_queue:dequeue()

    if item then
      self:send_request(item)
    end
  end
end

--- @param message_container table
function TsserverInstance:send_request(message_container)
  local seq = message_container.seq
  self.request_metadata[seq] = message_container

  if not message_container.is_async then
    self.pending_responses[seq] = true
  end

  self:write(message_container)
end

--- @private
--- @param message_container table
function TsserverInstance:write(message_container)
  local full_message = vim.tbl_extend("force", {
    seq = message_container.seq,
    type = "request",
  }, message_container.message)

  self.rpc:write(full_message)
end

--- @returns Methods:
--- - `notify()` |vim.lsp.rpc.notify()|
--- - `request()` |vim.lsp.rpc.request()|
--- - `is_closing()` returns a boolean indicating if the RPC is closing.
--- - `terminate()` terminates the RPC client.
function TsserverInstance:get_lsp_interface()
  return {
    request = function(method, params, callback, notify_reply_callback)
      if config.debug then
        vim.notify("request(" .. self.server_type .. "): " .. method, log.levels.INFO)
      end

      if method == constants.LspMethods.Initialize then
        -- INFO: this is additional request not handled by lsp it is pointless to return it's id
        self.request_queue:enqueue { message = global_initialize.configure() }
      end

      return self:handle_request(method, params, callback, notify_reply_callback)
    end,
    notify = function(method, params, ...)
      if config.debug then
        vim.notify("notify(" .. self.server_type .. "): " .. method, log.levels.INFO)
      end

      self:handle_request(method, params, ...)

      if method == constants.LspMethods.DidOpen then
        self.request_queue:enqueue { message = file_initialize.configure(params) }
      end
    end,
    is_closing = function()
      return self.rpc:is_closing()
    end,
    terminate = function()
      self.rpc:terminate()
    end,
  }
end

return TsserverInstance
