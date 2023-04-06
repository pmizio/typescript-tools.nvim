---@class Dispatchers
---@field notification fun(method: string, params: table)
---@field server_request fun(method: string, params: table): nil, table
---@field on_exit fun(code: number, signal: number)

---@alias LspCallback fun(err: any, result: any)

---@class LspInterface
---@field request fun(method: string, params: table|nil, callback: LspCallback, notify_reply_callback: function|nil): boolean, number:nil
---@field notify fun(method: string, params: table|nil): boolean
---@field terminate function
---@field is_closing fun(): boolean
