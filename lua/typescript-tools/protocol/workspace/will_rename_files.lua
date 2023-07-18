local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param code_edits table
local function add_text_edits(code_edits, changes)
  if not code_edits then
    return
  end

  for _, code_edit in ipairs(code_edits) do
    local uri = vim.uri_from_fname(code_edit.fileName)
    local text_edits = changes[uri] or {}

    for _, text_change in ipairs(code_edit.textChanges) do
      local text_edit = {
        newText = text_change.newText,
        range = utils.convert_tsserver_range_to_lsp(text_change),
      }
      table.insert(text_edits, text_edit)
    end

    changes[uri] = text_edits
  end
end

---@type TsserverProtocolHandler
function M.handler(request, response, params, ctx)
  local seqs = vim.tbl_map(function(file)
    local old_file_path = vim.uri_to_fname(file.oldUri)
    local new_file_path = vim.uri_to_fname(file.newUri)

    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L511
    return request {
      command = c.CommandTypes.GetEditsForFileRename,
      arguments = {
        oldFilePath = old_file_path,
        newFilePath = new_file_path,
      },
    }
  end, params.files)

  ctx.dependent_seq = seqs

  local changes = {}

  for _ in ipairs(seqs) do
    local body = coroutine.yield()

    add_text_edits(body, changes)
  end

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L511
  response {
    changes = changes,
  }
end

return M
