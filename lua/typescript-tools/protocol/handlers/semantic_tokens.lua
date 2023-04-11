local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local function lshift(x, by)
  return x * 2 ^ by
end

local function rshift(x, by)
  return math.floor(x / 2 ^ by)
end

local function bitwise_and(a, b)
  local result = 0
  local bitval = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then -- both bits are 1
      result = result + bitval
    end
    bitval = bitval * 2
    a = math.floor(a / 2)
    b = math.floor(b / 2)
  end
  return result
end

local TOKEN_ENCODING_TYPE_OFFSET = 8
local TOKEN_ENCODING_MODIFIER_MASK = lshift(1, TOKEN_ENCODING_TYPE_OFFSET) - 1

-- Transforms the semantic token spans given by the ts-server into lsp compatible spans.
-- @param spans the spans given by ts-server
-- @param requested_bufnr
-- @returns lsp compatible spans
local function transform_spans(spans, requested_bufnr)
  local lspSpans = {}
  local previousLine = 0
  local previousTokenStart = 0
  for i = 1, #spans, 3 do
    -- ts-server sends us a packed array that contains 3 elements per 1 token:
    -- 1. the start position of the token
    -- 2. length of the token
    -- 3. token type & modifier packed into a bitset
    local tokenStart = spans[i]
    local tokenLength = spans[i + 1]
    local tokenTypeBitSet = spans[i + 2]

    -- unpack the modifier and type: https://github.com/microsoft/TypeScript/blob/main/src/services/classifier2020.ts#L45
    local tokenModifier = bitwise_and(tokenTypeBitSet, TOKEN_ENCODING_MODIFIER_MASK)
    local tokenType = rshift(tokenTypeBitSet, TOKEN_ENCODING_TYPE_OFFSET) - 1

    local pos = utils.get_position_at_offset(tokenStart, requested_bufnr)
    local line, character = pos.line, pos.character

    -- lsp spec requires 5 elements per token instead of 3:
    -- 1. delta line number (relative to the previous line)
    -- 2. delta token start position (relative to the previous token)
    -- 3. length of the token
    -- 4. type of the token (e.g. function, comment, enum etc.)
    -- 5. token modifier (static, async etc.)
    local deltaLine = line - previousLine
    local deltaStart = previousLine == line and character - previousTokenStart or character

    table.insert(lspSpans, deltaLine)
    table.insert(lspSpans, deltaStart)
    table.insert(lspSpans, tokenLength)
    table.insert(lspSpans, tokenType)
    table.insert(lspSpans, tokenModifier)

    previousTokenStart = character
    previousLine = line
  end
  return lspSpans
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L879
local semantic_tokens_full_request_handler = function(_, params)
  local text_document = params.textDocument
  local start_offset = 0
  local requested_bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local end_offset = utils.get_offset_at_position(
    { vim.api.nvim_buf_line_count(requested_bufnr), 0 },
    requested_bufnr
  )

  return {
    command = constants.CommandTypes.EncodedSemanticClassificationsFull,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      start = start_offset,
      length = end_offset - start_offset,
      format = "2020",
    },
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L910
local semantic_tokens_full_response_handler = function(_, body, request_params)
  local requested_bufnr = vim.uri_to_bufnr(request_params.textDocument.uri)
  local err, result = pcall(transform_spans, body.spans, requested_bufnr)

  if not err then
    print([[[semantic_tokens.lua:100] -- result: ]] .. vim.inspect(result))
  end
  return { data = transform_spans(body.spans, requested_bufnr) }
end

return {
  request = {
    method = constants.LspMethods.SemanticTokensFull,
    handler = semantic_tokens_full_request_handler,
  },
  response = {
    method = constants.CommandTypes.EncodedSemanticClassificationsFull,
    handler = semantic_tokens_full_response_handler,
    schedule = true,
  },
}
