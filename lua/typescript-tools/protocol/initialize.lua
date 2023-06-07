local c = require "typescript-tools.protocol.constants"
local make_capabilities = require "typescript-tools.capabilities"
local TsserverProvider = require "typescript-tools.tsserver_provider"

local M = {}

local default_compiler_options = {
  module = "ESNext",
  target = "ES2020",
  jsx = "react",
  allowJs = true,
  strictNullChecks = true,
  sourceMap = true,
  allowSyntheticDefaultImports = true,
  allowNonTsExtensions = true,
  resolveJsonModule = true,
  moduleResolution = "Node",
  strictFunctionTypes = true,
}

---@type TsserverRequest
local configuration = {
  command = c.CommandTypes.Configure,
  arguments = {
    hostInfo = "neovim",
    preferences = {
      providePrefixAndSuffixTextForRename = true,
      allowRenameOfImportPath = true,
      includePackageJsonAutoImports = "auto",
    },
    watchOptions = {},
  },
}

local function read_compiler_options()
  local config_path = TsserverProvider.get_instance():get_tsconfig_path()

  if not config_path then
    return default_compiler_options
  end

  local ok, config = pcall(vim.json.decode, config_path:read(), { luanil = { object = true } })

  if ok and config then
    local compiler_options = config.compilerOptions or {}
    local ret = {}

    for k, v in pairs(default_compiler_options) do
      local value = compiler_options[k]

      if value ~= nil and v ~= value then
        ret[k] = value
      end
    end

    return ret
  end

  return default_compiler_options
end

---@return TsserverRequest
local function get_compiler_options()
  local opts = read_compiler_options()

  return {
    command = c.CommandTypes.CompilerOptionsForInferredProjects,
    arguments = {
      options = vim.tbl_extend("force", {}, default_compiler_options, opts),
    },
  }
end

---@type TsserverProtocolHandler
function M.handler(request, response)
  request(configuration)
  -- tssever protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/2b7d517907de7026c83e54ceab59a3926877a5d3/src/server/protocol.ts#L1914
  request(get_compiler_options())
  -- INFO: skip first response
  coroutine.yield()

  response { capabilities = make_capabilities() }
end

return M
