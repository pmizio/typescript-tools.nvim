local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"

local M = {}

---@param mode OrganizeImportsMode
function M.organize_imports(mode)
  local params = { file = vim.api.nvim_buf_get_name(0), mode = mode }

  vim.lsp.buf_request(0, c.CustomMethods.OrganizeImports, params)
end

---@param callback fun(params: table, result: table)|nil
function M.request_diagnostics(callback)
  local text_document = vim.lsp.util.make_text_document_params()
  local client = vim.lsp.get_active_clients {
    name = plugin_config.plugin_name,
    bufnr = vim.uri_to_bufnr(text_document.uri),
  }

  if #client == 0 then
    return
  end

  vim.lsp.buf_request(0, c.CustomMethods.Diagnostic, {
    textDocument = text_document,
  }, callback)
end

--- Returns an |lsp-handler| that filters TypeScript diagnostics with the given codes.
--- <pre>lua
--- local api = require('typescript-tools.api')
--- require('typescript-tools').setup {
---   handlers = {
---     -- Ignore 'This may be converted to an async function' diagnostics.
---     ['textDocument/publishDiagnostics'] = api.filter_diagnostics { 80006 }
---   }
--- }
--- </pre>
---
---@param codes integer[]
function M.filter_diagnostics(codes)
  vim.tbl_add_reverse_lookup(codes)
  return function(err, res, ctx, config)
    local filtered = {}
    for _, diag in ipairs(res.diagnostics) do
      if diag.source == "tsserver" and codes[diag.code] == nil then
        table.insert(filtered, diag)
      end
    end

    res.diagnostics = filtered
    vim.lsp.diagnostic.on_publish_diagnostics(err, res, ctx, config)
  end
end

return M
