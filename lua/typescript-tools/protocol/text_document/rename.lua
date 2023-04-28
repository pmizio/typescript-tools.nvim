local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param new_text string
---@param loc table
---@return string
local function format_new_name(new_text, loc)
  local buf = { new_text }

  if loc.prefixText then
    table.insert(buf, 1, loc.prefixText)
  end

  if loc.suffixText then
    table.insert(buf, loc.suffixText)
  end

  return table.concat(buf, "")
end

---@param new_text string
---@param locs table
---@return table
local function convert_tsserver_locs_to_changes(new_text, locs)
  local edits_per_file = {}

  for _, spanGroup in pairs(locs) do
    local uri = vim.uri_from_fname(spanGroup.file)

    edits_per_file[uri] = vim.tbl_map(function(loc)
      return {
        newText = format_new_name(new_text, loc),
        range = utils.convert_tsserver_range_to_lsp(loc),
      }
    end, spanGroup.locs)
  end

  return edits_per_file
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L930
  request {
    command = c.CommandTypes.Rename,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      -- TODO: expose as options
      findInComments = false,
      findInStrings = false,
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L993
  if not body.info.canRename then
    response(nil)
  end

  response {
    changes = convert_tsserver_locs_to_changes(params.newName, body.locs),
  }
end

return M
