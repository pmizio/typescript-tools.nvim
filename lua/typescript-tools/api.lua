local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local timeout = 1000 -- 1 secs

local M = {}

---@param bufnr integer
local function get_client(bufnr)
  local clients = vim.lsp.get_active_clients {
    name = plugin_config.plugin_name,
    bufnr = bufnr,
  }

  if #clients == 0 then
    return
  end

  return clients[1]
end

---@param error_codes table - table of all diagnostic codes
---@param fix_names table
---@param bufnr integer
---@param is_sync boolean
local function send_batch_code_action(error_codes, fix_names, bufnr, is_sync)
  local typescript_client = get_client(bufnr)

  if typescript_client == nil then
    return
  end

  local params = {
    diagnostics = vim.diagnostic.get(bufnr),
    bufnr = bufnr,
    error_codes = error_codes,
    fix_names = fix_names,
  }

  if is_sync then
    local res = typescript_client.request_sync(c.CustomMethods.BatchCodeActions, params, timeout, 0)
    if not res.err then
      vim.lsp.util.apply_workspace_edit(res.result.edit, "utf-8")
    end
  else
    typescript_client.request(c.CustomMethods.BatchCodeActions, params, function(err, res)
      if not err then
        vim.lsp.util.apply_workspace_edit(res.edit, "utf-8")
      end
    end, 0)
  end
end

---@param mode OrganizeImportsMode
---@param is_sync boolean
function M.organize_imports(mode, is_sync)
  local params = { file = vim.api.nvim_buf_get_name(0), mode = mode }

  if is_sync then
    local res = vim.lsp.buf_request_sync(0, c.CustomMethods.OrganizeImports, params, timeout)

    local typescript_client = get_client(0)
    if typescript_client == nil then
      return
    end

    local typescript_client_res = res[typescript_client.id]
    if not typescript_client_res.err then
      vim.lsp.util.apply_workspace_edit(typescript_client_res.result, "utf-8")
    end
  else
    vim.lsp.buf_request(0, c.CustomMethods.OrganizeImports, params)
  end
end

---@param is_sync boolean
function M.go_to_source_definition(is_sync)
  local params = vim.lsp.util.make_position_params()

  params.context = { source_definition = true }

  if is_sync then
    local res = vim.lsp.buf_request_sync(0, c.LspMethods.Definition, params, timeout)
    local typescript_client = get_client(0)
    if typescript_client == nil then
      return
    end
    local typescript_client_res = res[typescript_client.id]
    local context = {
      method = c.LspMethods.Definition,
      client_id = typescript_client.id,
      bufnr = 0,
      params = params,
    }
    if not typescript_client_res.err then
      vim.lsp.handlers[c.LspMethods.Definition](
        typescript_client_res.err,
        typescript_client_res.result,
        context
      )
    end
  else
    vim.lsp.buf_request(0, c.LspMethods.Definition, params, function(err, result, context)
      if not err then
        vim.lsp.handlers[c.LspMethods.Definition](err, result, context)
      end
    end)
  end
end

---@param is_sync boolean
function M.remove_unused(is_sync)
  local UNUSED_VARIABLE_CODES = { 6196, 6133 }
  local FIX_NAMES = { "unusedIdentifier" }

  send_batch_code_action(UNUSED_VARIABLE_CODES, FIX_NAMES, 0, is_sync)
end

---@param is_sync boolean
function M.add_missing_imports(is_sync)
  local MISSING_IMPORT_CODES = { 2552, 2304 }
  local FIX_NAMES = { "import" }

  send_batch_code_action(MISSING_IMPORT_CODES, FIX_NAMES, 0, is_sync)
end

---@param is_sync boolean
function M.fix_all(is_sync)
  local FIXABLE_ERROR_CODES = { 2420, 1308, 7027 }
  local FIX_NAMES =
    { "fixClassIncorrectlyImplementsInterface", "fixAwaitInSyncFunction", "fixUnreachableCode" }

  send_batch_code_action(FIXABLE_ERROR_CODES, FIX_NAMES, 0, is_sync)
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
