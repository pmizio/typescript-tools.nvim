local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

M.low_priority = true
M.cancel_on_change = true

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local implementations = params.data.implementations
  local request_params = {
    textDocument = params.data.textDocument,
    position = params.range.start,
  }

  local title = ""
  local arguments = {}

  if implementations then
    request(utils.tsserver_location_request(c.CommandTypes.Implementation, request_params))

    local body = coroutine.yield()

    if body then
      local range = utils.convert_lsp_range_to_tsserver(params.range)
      local filtered_body = vim.tbl_filter(function(imp)
        return not (
          vim.uri_from_fname(imp.file) == params.data.textDocument.uri
          and imp.start.line == range.start.line
          and imp.start.offset == range.start.offset
        )
      end, body)

      title = "implementations: " .. #filtered_body
      arguments = {
        textDocument = params.data.textDocument,
        position = params.range.start,
      }
    end
  else
    request(utils.tsserver_location_request(c.CommandTypes.References, request_params))

    local body = coroutine.yield()

    if body.refs then
      local refs = vim.tbl_filter(function(ref)
        return not ref.isDefinition
      end, body.refs)

      title = "references: " .. #refs
      arguments = {
        textDocument = params.data.textDocument,
        position = params.range.start,
      }
    end
  end

  if title == "" then
    response(nil)
    return
  end

  response {
    range = params.range,
    command = {
      title = title,
      command = implementations and c.InternalCommands.RequestImplementations
        or c.InternalCommands.RequestReferences,
      arguments = arguments,
    },
  }
end

return M
