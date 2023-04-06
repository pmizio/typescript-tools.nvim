local c = require "typescript-tools.protocol.constants"
local comm = require "typescript-tools.new.communication"
local make_capabilities = require "typescript-tools.capabilities"

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

---@param method string
---@param params table
---@return thread
local function initialize_handler(method, params)
  return coroutine.create(function()
    comm.queue_request(configuration, true)
    comm.await(initial_compiler_options)

    return { capabilities = make_capabilities() }
  end)
end

return initialize_handler
