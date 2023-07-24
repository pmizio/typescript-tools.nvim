local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local bufnr = vim.fn.bufnr "$"
  local buf_name = bufnr == -1 and "" or vim.api.nvim_buf_get_name(bufnr)

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/2da62a784bbba237b8239e84c8629cfafb0f595e/lib/protocol.d.ts#L2367
  request {
    command = c.CommandTypes.Navto,
    arguments = {
      searchValue = params.query,
      file = buf_name,
    },
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/2da62a784bbba237b8239e84c8629cfafb0f595e/lib/protocol.d.ts#L2409
  if not body then
    response {}
  end

  response(vim.tbl_map(function(item)
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
  end, body))
end

return M
