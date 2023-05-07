local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

---@param mode OrganizeImportsMode
---@return boolean
local function map_mode_to_skip_destructions(mode)
  return mode == c.OrganizeImportsMode.SortAndCombine
end

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function organize_imports_creator(_, params)
  local file = params.file
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L692
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.OrganizeImports,
    arguments = {
      scope = {
        args = {
          file = file,
        },
        type = "file",
      },
      skipDestructiveCodeActions = map_mode_to_skip_destructions(params.mode),
      mode = params.mode,
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L712
  ---@param body table
  ---@return table
  local function handler(body)
    return {
      changes = utils.convert_tsserver_edits_to_lsp(body),
    }
  end

  return request, handler
end

return organize_imports_creator
