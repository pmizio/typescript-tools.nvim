local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil
local function hover_creator(_, params)
  local text_document = params.textDocument
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1440
  ---@type TsserverRequest
  local request = {
    command = c.CommandTypes.Quickinfo,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1453
  ---@param body table
  ---@return table
  local function handler(body)
    local contents = {
      "\n",
      utils.tsserver_docs_to_plain_text(body.documentation),
      utils.tsserver_make_tags(body.tags),
    }

    if body.displayString then
      table.insert(contents, 1, {
        language = "typescript",
        value = body.displayString,
      })
    end

    return {
      contents = contents,
      range = utils.convert_tsserver_range_to_lsp(body),
    }
  end

  return request, handler
end

return hover_creator
