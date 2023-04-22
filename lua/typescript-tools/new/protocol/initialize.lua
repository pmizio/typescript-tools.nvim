local c = require "typescript-tools.new.protocol.constants"
local make_capabilities = require "typescript-tools.capabilities"
local protocol = require "typescript-tools.new.protocol"

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

---@type TsserverRequest
local initial_compiler_options = {
  command = c.CommandTypes.CompilerOptionsForInferredProjects,
  arguments = {
    options = {
      module = "ESNext",
      moduleResolution = "Node",
      target = "ES2020",
      jsx = "react",
      strictNullChecks = true,
      strictFunctionTypes = true,
      sourceMap = true,
      allowJs = true,
      allowSyntheticDefaultImports = true,
      allowNonTsExtensions = true,
      resolveJsonModule = true,
    },
  },
}

---@return TsserverRequest | TsserverRequest[], function|nil
local function initialize_creator()
  local requests = {
    configuration,
    initial_compiler_options,
  }

  ---@return table
  local function handler()
    coroutine.yield(protocol.multi_response)
    return { capabilities = make_capabilities() }
  end

  return requests, handler
end

return initialize_creator
