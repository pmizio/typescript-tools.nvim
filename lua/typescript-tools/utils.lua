local uv = vim.loop

local M = {}

---@param ms number
---@param fn function
---@return function, table
M.debounce = function(ms, fn)
  local timer = uv.new_timer()

  local wrapped_fn = function()
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end

  return wrapped_fn, timer
end

--- @param bufnr number
--- @return boolean
M.is_buf_hidden = function(bufnr)
  local bufinfo = vim.fn.getbufinfo(bufnr)[1]

  if bufinfo == nil then
    return true
  end

  return bufinfo.hidden == 1
end

return M
