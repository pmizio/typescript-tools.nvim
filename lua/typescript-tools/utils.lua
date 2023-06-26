local uv = vim.loop
local Path = require "plenary.path"

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

--- INFO: stealed from:
--- https://github.com/nvim-lua/plenary.nvim/blob/36aaceb6e93addd20b1b18f94d86aecc552f30c4/lua/plenary/path.lua#L57C1-L62C4
---@param path Path
---@return boolean
function M.is_root(path)
  local pathname = path:absolute()

  if Path.path.sep == "\\" then
    return string.match(pathname, "^[A-Z]:\\?$")
  end
  return pathname == "/"
end

return M
