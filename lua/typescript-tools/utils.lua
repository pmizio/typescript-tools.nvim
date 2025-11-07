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

---@return boolean, string
function M.check_minimum_nvim_version()
  local required_version = { 0, 11, 0 }
  local current_version = vim.version()

  local is_compatible = vim.version.ge(current_version, required_version)
  local version_str =
    string.format("%d.%d.%d", current_version.major, current_version.minor, current_version.patch)

  if is_compatible then
    return true, string.format("Neovim %s (>= 0.11 required)", version_str)
  else
    return false, string.format("Neovim %s found, but >= 0.11 is required", version_str)
  end
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

function M.bufname_valid(bufname)
  if
    bufname:match "^/"
    or bufname:match "^[a-zA-Z]:"
    or bufname:match "^zipfile://"
    or bufname:match "^tarfile:"
  then
    return true
  end
  return false
end

---@param startpath string
---@param func function
---@return string|nil
function M.search_ancestors(startpath, func)
  local guard = 100
  for path in vim.fs.parents(startpath) do
    -- Prevent infinite recursion if our algorithm breaks
    guard = guard - 1
    if guard == 0 then
      return
    end

    if func(path) then
      return path
    end
  end
end

---@param bufnr integer
---@return string
function M.get_root_dir(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local function has_tsconfig(path)
    return vim.fn.filereadable(vim.fn.join { path, "tsconfig.json" }) == 1
  end

  local function has_root_files(path)
    local root_files = { "jsconfig.json", "package.json", ".git" }
    for _, file in ipairs(root_files) do
      if vim.fn.filereadable(vim.fn.join({ path, file }, "/")) == 1 then
        return true
      end
    end
    return false
  end

  local root_dir = M.search_ancestors(fname, has_tsconfig)
    or M.search_ancestors(fname, has_root_files)
    or vim.fn.getcwd()

  -- INFO: this is needed to make sure we don't pick up root_dir inside node_modules
  local node_modules_index = root_dir and root_dir:find("node_modules", 1, true)
  if node_modules_index and node_modules_index > 0 then
    root_dir = root_dir:sub(1, node_modules_index - 2)
  end

  return root_dir
end

return M
