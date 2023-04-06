local M = {}

---@enum
M.RequestType = {
  SKIP = "skip",
  REGULAR = "regular",
  AWAIT = "await",
}

---@param request table
---@param skip_response boolean|nil
function M.queue_request(request, skip_response)
  if skip_response then
    coroutine.yield(request, M.RequestType.SKIP)
    return
  end

  coroutine.yield(request, M.RequestType.REGULAR)
end

---@param request table
function M.await(request)
  local data = request and coroutine.yield(request, M.RequestType.AWAIT) or coroutine.yield()

  return data.body or data
end

return M
