local a = require "plenary.async"
local utils = require "typescript-tools.utils"

local M = {}

local buf_request_async = a.wrap(vim.lsp.buf_request, 4)

local function buf_request_sync(bufnr, ...)
  local client = utils.get_typescript_client(bufnr)

  if not client then
    return nil, nil
  end

  local result, err = vim.lsp.buf_request_sync(bufnr, ...)

  if not result then
    return err, nil
  end

  local response = result[client.id]

  if not response then
    return nil, nil
  end

  return err or response.err, response.result
end

---@param is_sync boolean
---@param bufnr number
---@param method string
---@param params table
---@return any, table|nil
function M.buf_request_isomorphic(is_sync, ...)
  return (is_sync and buf_request_sync or buf_request_async)(...)
end

M.ui_input = a.wrap(vim.ui.input, 2)

return M
