local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local function as_folding_range_kind(span)
  if span.kind == "comment" then
    return constants.FoldingRangeKind.Comment
  elseif span.kind == "region" then
    return constants.FoldingRangeKind.Region
  elseif span.kind == "imports" then
    return constants.FoldingRangeKind.Imports
  else
    return nil
  end
end

local function as_folding_range(span)
  local range = utils.convert_tsserver_range_to_lsp(span.textSpan)
  local kind = as_folding_range_kind(span)

  -- TODO: how can we use vim.* here? I get E5560 lua-loop-callbacks error when
  -- calling e.g. api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line, false)

  -- workaround for https://github.com/Microsoft/vscode/issues/49904
  -- if kind == constants.FoldingRangeKind.Comment then
  --   -- local line = document:getLine(range.start.line)
  --   local line = api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line, false)[1]
  --   if string.match(line, "//%s*#endregion") then
  --     return nil
  --   end
  -- end

  -- workaround for https://github.com/Microsoft/vscode/issues/47240
  -- local lastCharacter = api.nvim_buf_get_text(
  --   0,
  --   range["end"].line,
  --   range["end"].character - 1,
  --   range["end"].line,
  --   range["end"].character,
  --   {}
  -- )
  -- local endLine = range["end"].character > 0
  --     and lastCharacter == "}"
  --     and math.max(range["end"].line - 1, range.start.line)
  --   or range["end"].line

  return {
    startLine = range.start.line,
    -- endLine = endLine,
    endLine = range["end"].line,
    kind = kind,
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/main/src/server/protocol.ts#L375
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
-- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1574
local folding_range_response_handler = function(_, body)
  local folding_ranges = vim.tbl_map(function(range)
    return as_folding_range(range)
  end, body)

  return vim.tbl_filter(function(folding_range)
    return folding_range ~= nil
  end, folding_ranges)
end

return {
  request = {
    method = constants.LspMethods.FoldingRange,
    handler = folding_range_request_handler,
  },
  response = {
    method = constants.CommandTypes.GetOutliningSpans,
    handler = folding_range_response_handler,
  },
}
