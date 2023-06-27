local api = vim.api
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local bit = require "bit"

local content_length_limit = 100000

local M = {}

M.low_priority = true
M.cancel_on_change = true
M.interrupt_diagnostic = false

local token_encoding_type_offset = 8
local token_encoding_modifier_mask = bit.lshift(1, token_encoding_type_offset) - 1

local newline_length_map = {
  dos = 2,
  unix = 1,
  mac = 1,
}

---@param bufnr number
---@return table<number, number> - { [linenr]: [utf-16 line length] }
local function get_buffer_lines_lengths(bufnr)
  local all_lines = api.nvim_buf_get_lines(bufnr, 0, vim.api.nvim_buf_line_count(bufnr), false)
  local newline_length = newline_length_map[vim.bo.fileformat]

  return vim.tbl_map(function(line)
    return vim.lsp.util._str_utfindex_enc(line, nil, "utf-16") + newline_length
  end, all_lines)
end

-- Given the buffer offset finds nvim line and character position in UTF-16 encoding
-- could not use `api.nvim_buf_get_offset` because it returns byte offset and
-- tsserver uses character offset. Uses offset_from_last_iteration and line_from_last_iteration
-- for performance. Tokens in tsserver response are positioned in ascending order so we don't need
-- to search whole file every token.
---@param offset number
---@param lines_lengths number[] - table with every line and instead of line length it has utf-16 line length
---@param offset_from_last_iteration number - offset to start with (performance)
---@param line_from_last_iteration number - line to start with (performance)
---@return LspPosition|nil, number|nil
local function get_character_position_at_offset(
  offset,
  lines_lengths,
  offset_from_last_iteration,
  line_from_last_iteration
)
  if #lines_lengths == 0 then
    return { line = 0, character = 0 }
  end

  if #lines_lengths == 1 then
    return { line = 0, character = offset }
  end

  local current_offset = offset_from_last_iteration

  for line = line_from_last_iteration, #lines_lengths, 1 do
    local current_line_length = lines_lengths[line + 1]
    local offset_with_current_line = current_offset + current_line_length

    if offset_with_current_line > offset then
      return { line = line, character = offset - current_offset }, current_offset
    end

    current_offset = offset_with_current_line
  end
end

-- Transforms the semantic token spans given by the ts-server into lsp compatible spans.
---@param spans TssPosition - the spans given by ts-server
---@param lines_lengths number[] - table with every line length in the file
---@return LspPosition[] - lsp compatible spans
local function transform_spans(spans, lines_lengths)
  local lsp_spans = {}
  local previous_line = 0
  local previous_token_start = 0
  ---@type number
  local previous_offset = 0

  for i = 1, #spans, 3 do
    -- ts-server sends us a packed array that contains 3 elements per 1 token:
    -- 1. the start offset of the token
    -- 2. length of the token
    -- 3. token type & modifier packed into a bitset
    local token_start_offset = spans[i]
    local token_length = spans[i + 1]
    local token_type_bit_set = spans[i + 2]

    -- unpack the modifier and type: https://github.com/microsoft/TypeScript/blob/main/src/services/classifier2020.ts#L45
    local token_modifier = bit.band(token_type_bit_set, token_encoding_modifier_mask)
    local token_type = bit.rshift(token_type_bit_set, token_encoding_type_offset) - 1

    local pos, last_line_offset = get_character_position_at_offset(
      token_start_offset,
      lines_lengths,
      previous_offset,
      previous_line
    )

    if pos then
      local line, character = pos.line, pos.character

      -- lsp spec requires 5 elements per token instead of 3:
      -- 1. delta line number (relative to the previous line)
      -- 2. delta token start offset (relative to the previous token)
      -- 3. length of the token
      -- 4. type of the token (e.g. function, comment, enum etc.)
      -- 5. token modifier (static, async etc.)
      local delta_line = line - previous_line
      local delta_start = previous_line == line and character - previous_token_start or character

      table.insert(lsp_spans, delta_line)
      table.insert(lsp_spans, delta_start)
      table.insert(lsp_spans, token_length)
      table.insert(lsp_spans, token_type)
      table.insert(lsp_spans, token_modifier)

      previous_token_start = character
      previous_line = line
      previous_offset = last_line_offset or 0
    end
  end

  return lsp_spans
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  local start_offset = 0
  local requested_bufnr = vim.uri_to_bufnr(text_document.uri)
  local line_count = api.nvim_buf_line_count(requested_bufnr)

  if api.nvim_buf_get_offset(requested_bufnr, line_count) >= content_length_limit then
    request {
      response = { data = {} },
    }
    return
  end

  local end_offset = utils.get_offset_at_position({ line_count, 0 }, requested_bufnr)
  local lines_lengths = get_buffer_lines_lengths(requested_bufnr)

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L879
  request {
    command = c.CommandTypes.EncodedSemanticClassificationsFull,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      start = start_offset,
      length = end_offset - start_offset,
      format = "2020",
    },
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/v5.0.2/src/server/protocol.ts#L910
  vim.schedule(function()
    response { data = transform_spans(body.spans or {}, lines_lengths) }
  end)
end

return M
