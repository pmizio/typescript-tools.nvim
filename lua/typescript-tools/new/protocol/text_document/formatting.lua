local api = vim.api
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local function map_formatting_options(options)
  if not options then
    return nil
  end

  return {
    convertTabsToSpaces = options.insertSpaces,
    tabSize = options.tabSize,
  }
end

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function formatting_creator(_, params)
  local text_document = params.textDocument
  local range = params.range

  if not range then
    local last_line = api.nvim_buf_line_count(0)
    local last_line_content = api.nvim_buf_get_lines(0, last_line - 1, last_line, true)[1] or ""
    local last_char = #last_line_content

    range = {
      start = {
        line = 0,
        character = 0,
      },
      ["end"] = {
        line = last_line > 0 and last_line - 1 or 0,
        character = last_char > 0 and last_char - 1 or 0,
      },
    }
  end

  range = utils.convert_lsp_range_to_tsserver(range)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1493
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.Format,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      line = range.start.line,
      offset = range.start.offset,
      endLine = range["end"].line,
      endOffset = range["end"].offset,
      options = map_formatting_options(params.options),
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/e14a2298c5add93816c6f487bcfc5ac72e3a4c59/lib/protocol.d.ts#L1574
  ---@param body table
  ---@return table
  local function handler(body)
    return vim.tbl_map(function(edit)
      return {
        newText = edit.newText,
        range = utils.convert_tsserver_range_to_lsp(edit),
      }
    end, body)
  end

  return request, handler
end

return formatting_creator
