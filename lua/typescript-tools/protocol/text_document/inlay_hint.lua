local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

---@enum inlay_hint_kind
local inlay_hint_kind_map = {
  Type = 1,
  Parameter = 2,
}

---@param filetype string
---@return boolean
local function are_inlay_hints_enabled(filetype)
  local preferences = plugin_config.get_tsserver_file_preferences(filetype)

  if not preferences then
    return false
  end

  return preferences.includeInlayParameterNameHints ~= "none"
    or preferences.includeInlayEnumMemberValueHints
    or preferences.includeInlayFunctionLikeReturnTypeHints
    or preferences.includeInlayFunctionParameterTypeHints
    or preferences.includeInlayPropertyDeclarationTypeHints
    or preferences.includeInlayVariableTypeHints
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  local requested_bufnr = vim.uri_to_bufnr(params.textDocument.uri)

  if not are_inlay_hints_enabled(vim.bo[requested_bufnr].filetype) then
    return
  end

  local start_offset = utils.get_offset_at_position(
    { params.range.start.line, params.range.start.character },
    requested_bufnr
  )
  local end_offset = utils.get_offset_at_position(
    { params.range["end"].line, params.range["end"].character },
    requested_bufnr
  )

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L2632
  request {
    command = constants.CommandTypes.ProvideInlayHints,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      start = start_offset,
      length = end_offset - start_offset,
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L2656
  local body = coroutine.yield()

  response(vim.tbl_map(function(hint_response)
    return {
      position = utils.convert_tsserver_position_to_lsp(hint_response.position),
      label = hint_response.text,
      kind = inlay_hint_kind_map[hint_response.kind],
      paddingLeft = hint_response.whitespaceBefore and true or false,
      paddingRight = hint_response.whitespaceAfter and true or false,
    }
  end, body))
end

return M
