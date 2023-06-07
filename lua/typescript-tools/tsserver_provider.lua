local api = vim.api
local Path = require "plenary.path"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"

local plugin_config = require "typescript-tools.config"

---@class TsserverProvider
---@field private instance TsserverProvider
---@field private root_dir Path
---@field private npm_global_path Path

---@class TsserverProvider
local TsserverProvider = {}

---@private
---@return TsserverProvider
function TsserverProvider.new()
  local self = setmetatable({}, { __index = TsserverProvider })

  local config = configs[plugin_config.plugin_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  assert(util.bufname_valid(bufname), "Invalid buffer name!")

  self.root_dir = Path:new(config.get_root_dir(util.path.sanitize(bufname), bufnr))
  self.npm_global_path = Path
    :new(vim.fn.system([[node -p "process.execPath"]]):match "^%s*(.-)%s*$")
    :parent()
    :joinpath("..", "lib")

  return self
end

---@return TsserverProvider
function TsserverProvider.get_instance()
  if not TsserverProvider.instance then
    TsserverProvider.instance = TsserverProvider.new()
  end

  return TsserverProvider.instance
end

---@param path Path
---@return boolean|nil
local function tsserver_exists(path)
  return path:exists() and path:is_file()
end

---@return Path
function TsserverProvider:get_executable_path()
  local tsserver_path = self.root_dir:joinpath("node_modules", "typescript", "lib", "tsserver.js")

  if not tsserver_exists(tsserver_path) then
    tsserver_path =
      self.npm_global_path:joinpath("node_modules", "typescript", "lib", "tsserver.js")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    tsserver_exists(tsserver_path),
    "Cannot find tsserver executable in local project nor global npm installation."
  )

  return tsserver_path
end

---@return Path|nil
function TsserverProvider:get_plugins_path()
  if not self.npm_global_path:exists() then
    return nil
  end

  return self.npm_global_path
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
