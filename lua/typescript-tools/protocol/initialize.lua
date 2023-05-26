local c = require "typescript-tools.protocol.constants"
local capabilities = require "typescript-tools.capabilities"
local config = require "typescript-tools.config"

local M = {}

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

---@type TsserverProtocolHandler
function M.handler(request, response)
  request(configuration)
  request(initial_compiler_options)
  -- INFO: skip first response
  coroutine.yield()

  if config.code_lens == config.code_lens_mode.off then
    capabilities.codeLensProvider = false
  end

  response { capabilities = capabilities }
end

return M
