local a = require "plenary.async"
local utils = require "typescript-tools.utils"

local M = {}

local buf_request_async = a.wrap(vim.lsp.buf_request_all, 4)

---@param is_sync boolean
---@param bufnr number
---@param method string
---@param params table
---@return any, table|nil
function M.buf_request_isomorphic(is_sync, bufnr, ...)
  local client = utils.get_typescript_client(bufnr)

  if not client then
    return nil, nil
  end

  local result, err = (is_sync and vim.lsp.buf_request_sync or buf_request_async)(bufnr, ...)

  if not result then
    return err, nil
  end

  local response = result[client.id]

  if not response then
    return nil, nil
  end

  return err or response.err, response.result
end

M.ui_input = a.wrap(vim.ui.input, 2)

return M
