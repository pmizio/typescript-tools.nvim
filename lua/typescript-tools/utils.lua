local uv = vim.loop
local plugin_config = require "typescript-tools.config"

local M = {}

---@param ms number
---@param fn function
---@return function, table
function M.debounce(ms, fn)
  local timer = uv.new_timer()

  local function wrapped_fn()
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end

  return wrapped_fn, timer
end

---@param ms number
---@param fn function
---@return function, table
function M.throttle(ms, fn)
  local timer = vim.loop.new_timer()
  local running = false

  local argv, argc
  local function wrapped_fn(...)
    argv = { ... }
    argc = select("#", ...)

    if not running then
      timer:start(ms, 0, function()
        running = false
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
      running = true
    end
  end

  return wrapped_fn, timer
end

---@param bufnr number
---@return boolean
function M.is_buf_hidden(bufnr)
  local bufinfo = vim.fn.getbufinfo(bufnr)[1]

  if bufinfo == nil then
    return true
  end

  return bufinfo.hidden == 1
end

---@param mode "lt"|"gt"|"eq"
---@param version1 Version|nil
---@param version2 number[]
function M.version_compare(mode, version1, version2)
  if version1 == nil then
    return false
  end

  return vim.version[mode](version1, version2)
end

---@return boolean
function M.is_nightly()
  local v = vim.version().prerelease

  return type(v) ~= "boolean" and v ~= nil or v
end

function M.get_clients(filter)
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  return get_clients(filter)
end

---@param bufnr integer
---@return lsp.Client|nil
function M.get_typescript_client(bufnr)
  local clients = M.get_clients {
    name = plugin_config.plugin_name,
    bufnr = bufnr,
  }

  if #clients == 0 then
    return
  end

  return clients[1]
end

--- @generic T
--- @param list T[]
--- @param value T
--- @return boolean
function M.list_contains(list, value)
  if vim.list_contains ~= nil then
    return vim.list_contains(list, value)
  end
  for _, v in ipairs(list) do
    if value == v then
      return true
    end
  end

  return false
end

--- @param tbl table
function M.add_reverse_lookup(tbl)
  local keys = vim.tbl_keys(tbl)
  for _, k in ipairs(keys) do
    local v = tbl[k]
    tbl[v] = k
  end
end

return M
