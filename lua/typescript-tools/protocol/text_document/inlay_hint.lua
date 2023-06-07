local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

local INLAY_HINT_KIND_MAP = {
  Type = 1,
  Parameter = 2,
}

local function are_inlay_hints_enabled()
  local preferences = plugin_config.tsserver_file_preferences
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

function M.handler(request, response, params)
  if not are_inlay_hints_enabled() then
    return {}
  end

  local text_document = params.textDocument
  local requested_bufnr = vim.uri_to_bufnr(params.textDocument.uri)
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
      kind = INLAY_HINT_KIND_MAP[hint_response.kind],
      paddingLeft = hint_response.whitespaceBefore and true or false,
      paddingRight = hint_response.whitespaceAfter and true or false,
    }
  end, body))
end

return M
