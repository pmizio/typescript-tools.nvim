local constants = require "typescript-tools.protocol.constants"
local handlers = require "typescript-tools.protocol.handlers"
local make_protocol_handlers = require "typescript-tools.protocol.handlers"

local M = {}

M.constants = constants
M.handlers = handlers

M.request_handlers, M.response_handlers = make_protocol_handlers()

return M
