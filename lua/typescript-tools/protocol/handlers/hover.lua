local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1440
local hover_request_handler = function(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.Quickinfo,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/7910c509c4545517489d6264571bb6c05248fb4a/lib/protocol.d.ts#L1453
local hover_response_handler = function(_, body)
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

return {
  request = { method = constants.LspMethods.Hover, handler = hover_request_handler },
  response = { method = constants.CommandTypes.Quickinfo, handler = hover_response_handler },
}
