local log = require "vim.lsp.log"
local api = vim.api
local Path = require "plenary.path"
local Job = require "plenary.job"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"

local plugin_config = require "typescript-tools.config"

local is_win = vim.loop.os_uname().version:find "Windows"

---@class TsserverProvider
---@field private instance TsserverProvider
---@field private callbacks function[]
---@field private root_dir Path
---@field private npm_local_path Path
---@field private yarn_sdk_path Path
---@field private npm_global_path Path
---@field private global_install_path Path

---@class TsserverProvider
local TsserverProvider = {
  callbacks = {},
}

---@param path Path
---@return boolean|nil
local function tsserver_exists(path)
  return path:exists() and path:is_file()
end

---@param startpath string
---@return Path
local function find_deep_node_modules_ancestor(startpath)
  return Path:new(util.search_ancestors(startpath, function(path)
    local tsserver_path = Path:new(path, "node_modules", "typescript", "lib", "tsserver.js")

    if tsserver_exists(tsserver_path) then
      return path
    end
  end))
end

---@param startpath string
---@return Path
local function find_yarn_sdk(startpath)
  return Path:new(util.search_ancestors(startpath, function(path)
    local tsserver_path = Path:new(path, ".yarn", "sdks", "typescript", "lib", "tsserver.js")

    if tsserver_exists(tsserver_path) then
      return path
    end
  end))
end

---@private
---@return TsserverProvider
function TsserverProvider.new(on_loaded)
  local self = setmetatable({}, { __index = TsserverProvider })

  local config = configs[plugin_config.plugin_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  assert(util.bufname_valid(bufname), "Invalid buffer name!")

  local sanitized_bufname = util.path.sanitize(bufname)

  self.root_dir = Path:new(config.get_root_dir(sanitized_bufname, bufnr))
  self.npm_local_path = find_deep_node_modules_ancestor(sanitized_bufname):joinpath "node_modules"
  self.yarn_sdk_path = find_yarn_sdk(sanitized_bufname):joinpath ".yarn/sdks"
  self.global_install_path = Path:new(vim.fn.resolve(vim.fn.exepath "tsserver")):parent():parent()

  local command, args = self:make_npm_root_params()

  Job:new({
    command = command,
    args = args,
    on_stdout = function(_, data)
      ---@diagnostic disable-next-line
      TsserverProvider.npm_global_path = Path:new(vim.trim(data))
      on_loaded()
    end,
  }):start()

  return self
end

---@private
---@return string, string[]
function TsserverProvider:make_npm_root_params() -- luacheck: ignore
  local args = { "root", "-g" }

  if is_win then
    return "cmd.exe", { "/c", "npm", unpack(args) }
  end

  return "npm", args
end

---@param on_loaded function
function TsserverProvider.init(on_loaded)
  if not TsserverProvider.npm_global_path then
    table.insert(TsserverProvider.callbacks, on_loaded)
    TsserverProvider.instance = TsserverProvider.new(function()
      for _, callback in ipairs(TsserverProvider.callbacks) do
        callback()
      end
      TsserverProvider.callbacks = {}
    end)
  else
    on_loaded()
  end
end

---@return TsserverProvider
function TsserverProvider.get_instance()
  return TsserverProvider.instance
end

---@return Path|nil
local function get_tsserver_from_mason()
  local mason_path = os.getenv "MASON"
  if mason_path then
    local tsserver_path = Path:new(mason_path, "packages", "typescript-language-server")

    if (plugin_config.tsserver_path or ""):find(tsserver_path:absolute(), 1, true) then
      vim.schedule_wrap(vim.notify_once)(
        "[typescript-tools] We detected usage of `tsserver_path` to integrate with Mason. "
          .. "This integration is now built-in you can remove unnecessary code from your config.",
        vim.log.levels.WARN
      )
    end

    return tsserver_path:joinpath "node_modules"
  end

  return nil
end

---@return Path
function TsserverProvider:get_executable_path()
  local mason_tsserver = get_tsserver_from_mason()
  if plugin_config.tsserver_path then
    local tsserver_path = Path:new(plugin_config.tsserver_path)

    if tsserver_exists(tsserver_path) then
      local _ = log.trace() and log.trace("tsserver", "Binary found at:", tsserver_path:absolute())
      return tsserver_path
    end
  end

  local tsserver_path = self.root_dir:joinpath("node_modules", "typescript", "lib", "tsserver.js")

  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path = Path:new(self.npm_local_path, "typescript", "lib", "tsserver.js")
  end

  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path = Path:new(self.yarn_sdk_path, "typescript", "lib", "tsserver.js")
  end

  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path = TsserverProvider.npm_global_path:joinpath("typescript", "lib", "tsserver.js")
  end

  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path = self.global_install_path:joinpath("lib", "tsserver.js")
  end

  if mason_tsserver and not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path = mason_tsserver:joinpath("typescript", "lib", "tsserver.js")
  end

  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
  end

  -- INFO: to resolve tsserver in Nix store
  if not tsserver_exists(tsserver_path) then
    local _ = log.trace() and log.trace("tsserver", tsserver_path:absolute(), "not exists.")
    tsserver_path =
      self.global_install_path:joinpath("lib", "node_modules", "typescript", "lib", "tsserver.js")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    tsserver_exists(tsserver_path),
    "Cannot find tsserver executable in local project nor global npm installation."
  )

  local _ = log.trace() and log.trace("tsserver", "Binary found at:", tsserver_path:absolute())

  return tsserver_path
end

---@return Path|nil
function TsserverProvider:get_plugins_path() -- luacheck: ignore
  if not TsserverProvider.npm_global_path:exists() then
    return nil
  end

  return TsserverProvider.npm_global_path
end

---@return Path|nil
function TsserverProvider:get_tsconfig_path()
  local tsconfig = Path:new(self.root_dir, "tsconfig.json")

  if tsconfig:exists() then
    return tsconfig
  end

  local jsconfig = Path:new(self.root_dir, "jsconfig.json")

  if jsconfig:exists() then
    return jsconfig
  end

  return nil
end

---@return Version|nil
function TsserverProvider:get_version()
  ---@type Path
  local package_json_path = self:get_executable_path():parent():joinpath("..", "package.json")

  if not tsserver_exists(package_json_path) then
    return nil
  end

  local ok, package_json =
    pcall(vim.json.decode, package_json_path:read(), { luanil = { object = true } })

  if ok and package_json then
    return vim.version.parse(package_json.version)
  end

  return nil
end

return TsserverProvider
