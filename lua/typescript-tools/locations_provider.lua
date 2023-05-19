local api = vim.api
local Path = require "plenary.path"
local configs = require "lspconfig.configs"
local util = require "lspconfig.util"

local plugin_config = require "typescript-tools.config"

---@class LocationsProvider
---@field private root_dir string
---@field private npm_global_path string

---@class LocationsProvider
local LocationsProvider = {}

---@return LocationsProvider
function LocationsProvider:new()
  local obj = {}

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function LocationsProvider:initialize()
  local config = configs[plugin_config.plugin_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  assert(util.bufname_valid(bufname), "Invalid buffer name!")

  self.root_dir = config.get_root_dir(util.path.sanitize(bufname), bufnr)
  self.npm_global_path = vim.fn
    .system([[node -p "require('path').resolve(process.execPath, '../..')"]])
    :match "^%s*(.-)%s*$"
end

---@param path table - plenary.nvim path object
---@return boolean
function LocationsProvider:tsserver_exists(path)
  return path:exists() and path:is_file()
end

---@return table - plenary.nvim path object
function LocationsProvider:get_tsserver_path()
  local tsserver_path = Path:new(self.root_dir, "node_modules", "typescript", "lib", "tsserver.js")

  if not self:tsserver_exists(tsserver_path) then
    tsserver_path = Path:new(self.npm_global_path, "bin", "tsserver")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    self:tsserver_exists(tsserver_path),
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

return LocationsProvider:new()
