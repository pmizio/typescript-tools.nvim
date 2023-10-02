local ts = vim.treesitter
local config = require "typescript-tools.config"

local M = {}

---@param tree TSTree
---@param query Query
---@param text_document table
---@param lenses table
---@param implementations boolean|nil
local function convert_nodes_to_response(tree, query, text_document, lenses, implementations)
  for _, match in query:iter_matches(tree:root(), vim.uri_to_bufnr(text_document.uri)) do
    for id, node in pairs(match) do
      local name = query.captures[id]
      local start_row, start_col, end_row, end_col = node:range()

      if config.disable_member_code_lens and name == "member" then
        goto continue
      end

      table.insert(lenses, {
        range = {
          start = { line = start_row, character = start_col },
          ["end"] = { line = end_row, character = end_col },
        },
        data = {
          textDocument = text_document,
          implementations = implementations,
        },
      })
      ::continue::
    end
  end
end

---@type TsserverProtocolHandler
function M.handler(request, _, params)
  local text_document = params.textDocument
  local ok, parser = pcall(ts.get_parser)

  if not ok then
    vim.notify_once(
      "[typescript-tools] CodeLens feature use treesitter if you see this message you probably "
        .. "don't have parsers installed.",
      vim.log.levels.WARN
    )
    request {
      response = {},
    }
    return
  end

  local tree = parser:parse()[1]

  if not tree then
    request {
      response = {},
    }
    return
  end

  local lenses = {}
  local lang = parser:lang()

  if config.code_lens ~= config.code_lens_mode.references_only then
    local query = ts.query.get(lang, "implementations")

    if query then
      convert_nodes_to_response(tree, query, text_document, lenses, true)
    end
  end

  if config.code_lens ~= config.code_lens_mode.implementations_only then
    local query = ts.query.get(lang, "references")

    if query then
      convert_nodes_to_response(tree, query, text_document, lenses)
    end
  end

  request {
    response = lenses,
  }
end

return M
