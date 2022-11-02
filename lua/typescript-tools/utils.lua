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

return M
