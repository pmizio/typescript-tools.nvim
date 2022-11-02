local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/2da62a784bbba237b8239e84c8629cfafb0f595e/lib/protocol.d.ts#L2367
local workspace_symbol_request_handler = function(_, params)
  local buf_name = vim.api.nvim_buf_get_name(0)

  return {
    command = constants.CommandTypes.Navto,
    arguments = {
      searchValue = params.query,
      file = buf_name,
    },
  }
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/2da62a784bbba237b8239e84c8629cfafb0f595e/lib/protocol.d.ts#L2409
local workspace_symbol_response_handler = function(_, body)
  if not body then
    return {}
  end

  return vim.tbl_map(function(item)
    return {
      name = item.name,
      kind = utils.get_lsp_symbol_kind(item.kind),
      containerName = item.containerName,
      location = {
        uri = vim.uri_from_fname(item.file),
        range = utils.convert_tsserver_range_to_lsp(item),
      },
      -- INFO: lsp support only deprecated tag and it is 1 so for now it is hardoceded
      tags = (item.kindModifiers or ""):find("deprecated", 1, true) and { 1 } or nil,
    }
  end, body)
end

return {
  request = {
    method = constants.LspMethods.WorkspaceSymbol,
    handler = workspace_symbol_request_handler,
  },
  response = {
    method = constants.CommandTypes.Navto,
    handler = workspace_symbol_response_handler,
  },
}
