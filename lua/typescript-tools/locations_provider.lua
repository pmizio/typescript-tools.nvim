local api = vim.api
local Path = require "plenary.path"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"

local plugin_config = require "typescript-tools.config"

---@class LocationsProvider
---@field private instance LocationsProvider
---@field private root_dir string
---@field private npm_global_path string

---@class LocationsProvider
local LocationsProvider = {}

---@private
---@return LocationsProvider
function LocationsProvider.new()
  local self = setmetatable({}, { __index = LocationsProvider })

  local config = configs[plugin_config.plugin_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  assert(util.bufname_valid(bufname), "Invalid buffer name!")

  self.root_dir = config.get_root_dir(util.path.sanitize(bufname), bufnr)
  self.npm_global_path = vim.fn
    .system([[node -p "require('path').resolve(process.execPath, '../..')"]])
    :match "^%s*(.-)%s*$"

  return self
end

function LocationsProvider.get_instance()
  if not LocationsProvider.instance then
    LocationsProvider.instance = LocationsProvider.new()
  end

  return LocationsProvider.instance
end

---@param path table - plenary.nvim path object
---@return boolean
local function tsserver_exists(path)
  return path:exists() and path:is_file()
end

---@return table - plenary.nvim path object
function LocationsProvider:get_tsserver_path()
  local tsserver_path = Path:new(self.root_dir, "node_modules", "typescript", "lib", "tsserver.js")

  if not tsserver_exists(tsserver_path) then
    tsserver_path = Path:new(self.npm_global_path, "bin", "tsserver")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    tsserver_exists(tsserver_path),
    "Cannot find tsserver executable in local project nor global npm installation."
  )

  return tsserver_path
end

---@return table|nil - plenary.nvim path object
function LocationsProvider:get_tsserver_plugins_path()
  local plugins_path = Path:new(self.npm_global_path, "lib")

  if not plugins_path:exists() then
    return nil
  end

  return plugins_path
end

---@return table|nil - plenary.nvim path object
function LocationsProvider:get_tsconfig_path()
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

return LocationsProvider
