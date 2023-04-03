local uv = vim.loop

local M = {}

---@param ms number
---@param fn function
---@return function, uv.uv_timer_t|uv_timer_t|nil
M.debounce = function(ms, fn)
  local timer = uv.new_timer()

  local wrapped_fn = function(...)
    if not timer then
      vim.schedule_wrap(vim.notify)("Cannot create luv timer!", vim.log.levels.ERROR)
      return
    end

    local args = ...

    timer:stop()
    timer:start(ms, 0, function()
      vim.schedule_wrap(fn)(args)
    end)
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
