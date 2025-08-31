local uv = vim.loop
local plugin_config = require "typescript-tools.config"
local c = require "typescript-tools.protocol.constants"

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
---@return vim.lsp.Client|nil
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

-- Returns a function that only runs the given function once.
--- @param func function
function M.run_once(func)
  local ran = false
  return function(...)
    if not ran then
      ran = true
      return func(...)
    end
  end
end

---@param result? table
---@param opts? vim.lsp.ListOpts
function M.on_definition_response(_, result, _, opts)
  opts = opts or {}
  local locations = {}
  if result then
    locations = vim.islist(result) and result or { result }
  end
  local all_items = vim.lsp.util.locations_to_items(locations, "utf-8")
  if vim.tbl_isempty(all_items) then
    vim.notify("No locations found", vim.log.levels.INFO)
    return
  end

  local title = "LSP locations"
  if opts.on_list then
    assert(vim.is_callable(opts.on_list), "on_list is not a function")
    opts.on_list {
      title = title,
      items = all_items,
      context = { bufnr = 0, method = c.LspMethods.Definition },
    }
    return
  end

  if #all_items == 1 then
    local item = all_items[1]
    local b = item.bufnr or vim.fn.bufadd(item.filename)

    -- Save position in jumplist
    vim.cmd "normal! m'"
    -- Push a new item into tagstack
    local tagname = vim.fn.expand "<cword>"
    local from = vim.fn.getpos "."
    local win = vim.api.nvim_get_current_win()

    local tagstack = { { tagname = tagname, from = from } }
    vim.fn.settagstack(vim.fn.win_getid(win), { items = tagstack }, "t")

    vim.bo[b].buflisted = true
    local w = opts.reuse_win and vim.fn.win_findbuf(b)[1] or win
    vim.api.nvim_win_set_buf(w, b)
    vim.api.nvim_win_set_cursor(w, { item.lnum, item.col - 1 })
    vim._with({ win = w }, function()
      -- Open folds under the cursor
      vim.cmd "normal! zv"
    end)
    return
  end

  if opts.loclist then
    vim.fn.setloclist(0, {}, " ", { title = title, items = all_items })
    vim.cmd.lopen()
  else
    vim.fn.setqflist({}, " ", { title = title, items = all_items })
    vim.cmd "botright copen"
  end
end

return M
