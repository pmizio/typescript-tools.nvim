local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

local tsserver_fold_kind_to_lsp_map = {
  comment = c.FoldingRangeKind.Comment,
  region = c.FoldingRangeKind.Region,
  imports = c.FoldingRangeKind.Imports,
}

---@param range LspRange
---@param bufnr number
---@return string|nil
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

---@param span table
---@param bufnr number
---@return table?
local function as_folding_range(span, bufnr)
  if not span.textSpan then
    return nil
  end

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

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L377
  request {
    command = c.CommandTypes.GetOutliningSpans,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
    },
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L406
  vim.schedule(function()
    local requested_bufnr = vim.uri_to_bufnr(params.textDocument.uri)

    local ranges = {}

    for _, span in ipairs(body) do
      local folding_range = as_folding_range(span, requested_bufnr)

      if span.textSpan then
        table.insert(ranges, folding_range)
      end
    end

    response(ranges)
  end)
end

return M
