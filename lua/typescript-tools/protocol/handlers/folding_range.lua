local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local tsserver_fold_kind_to_lsp_map = {
  comment = constants.FoldingRangeKind.Comment,
  region = constants.FoldingRangeKind.Region,
  imports = constants.FoldingRangeKind.Imports,
}

local function get_last_character(range, bufnr)
  -- when file changes between request and response vim.api.nvim_buf_get_text
  -- returns Index out of bounds
  local err, last_character_lines = pcall(
    vim.api.nvim_buf_get_text,
    bufnr,
    range["end"].line,
    range["end"].character - 1,
    range["end"].line,
    range["end"].character,
    {}
  )

  if not err then
    return nil
  end

  return last_character_lines[1]
end

local function as_folding_range(span, bufnr)
  local range = utils.convert_tsserver_range_to_lsp(span.textSpan)
  local kind = tsserver_fold_kind_to_lsp_map[span.kind]

  -- workaround for https://github.com/Microsoft/vscode/issues/47240
  local lastCharacter = get_last_character(range, bufnr)
  local endLine = range["end"].character > 0
      and (lastCharacter == "}" or lastCharacter == "]")
      and math.max(range["end"].line - 1, range.start.line)
    or range["end"].line

  return {
    startLine = range.start.line,
    endLine = endLine,
    kind = kind,
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L377
local folding_range_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.GetOutliningSpans,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
    },
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L406
local folding_range_response_handler = function(_, body, request_params)
  local requested_bufnr = vim.uri_to_bufnr(request_params.textDocument.uri)

  return vim.tbl_map(function(range)
    return as_folding_range(range, requested_bufnr)
  end, body)
end

return {
  request = {
    method = constants.LspMethods.FoldingRange,
    handler = folding_range_request_handler,
  },
  response = {
    method = constants.CommandTypes.GetOutliningSpans,
    handler = folding_range_response_handler,
    schedule = true,
  },
}
