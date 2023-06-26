local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local batch_code_fixes = require "typescript-tools.custom-commands.batch_code_fixes"

local M = {}

---@param mode OrganizeImportsMode
function M.organize_imports(mode)
  local params = { file = vim.api.nvim_buf_get_name(0), mode = mode }

  vim.lsp.buf_request(0, c.CustomMethods.OrganizeImports, params)
end

function M.remove_unused()
  local UNUSED_VARIABLE_CODES = { 6196, 6133 }
  local FIX_NAME = { "unusedIdentifier" }

  local workspace_edit =
    batch_code_fixes.get_batch_code_fix_updates(UNUSED_VARIABLE_CODES, FIX_NAME)

  if workspace_edit then
    vim.lsp.util.apply_workspace_edit(workspace_edit, "utf-8")
  end
end

function M.add_missing_imports()
  local MISSING_IMPORT_CODES = { 2552, 2304 }
  local FIX_NAME = { "import" }

  local workspace_edit = batch_code_fixes.get_batch_code_fix_updates(MISSING_IMPORT_CODES, FIX_NAME)

  if workspace_edit then
    vim.lsp.util.apply_workspace_edit(workspace_edit, "utf-8")
  end
end

function M.fix_all()
  local FIXABLE_ERROR_CODES = { 2420, 1308, 7027 }
  local FIX_NAME =
    { "fixClassIncorrectlyImplementsInterface", "fixAwaitInSyncFunction", "fixUnreachableCode" }

  local workspace_edit = batch_code_fixes.get_batch_code_fix_updates(FIXABLE_ERROR_CODES, FIX_NAME)

  if workspace_edit then
    vim.lsp.util.apply_workspace_edit(workspace_edit, "utf-8")
  end
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

return M
