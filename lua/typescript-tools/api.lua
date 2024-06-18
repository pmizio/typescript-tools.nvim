local a = require "plenary.async"
local uv = require "plenary.async.uv_async"
local au = require "plenary.async.util"
local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local async = require "typescript-tools.async"
local utils = require "typescript-tools.utils"

local timeout = 1000 -- 1 secs

local get_typescript_client = utils.get_typescript_client

local M = {}

---@param error_codes table - table of all diagnostic codes
---@param fix_names table
---@param bufnr integer
---@param is_sync boolean
local function send_batch_code_action(error_codes, fix_names, bufnr, is_sync)
  local typescript_client = get_typescript_client(bufnr)

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
local function organize_imports_mode(mode, is_sync)
  local params = { file = vim.api.nvim_buf_get_name(0), mode = mode }

  if is_sync then
    local res = vim.lsp.buf_request_sync(0, c.CustomMethods.OrganizeImports, params, timeout)

    local typescript_client = get_typescript_client(0)
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

function M.organize_imports(is_sync)
  organize_imports_mode(c.OrganizeImportsMode.All, is_sync)
end

function M.sort_imports(is_sync)
  organize_imports_mode(c.OrganizeImportsMode.SortAndCombine, is_sync)
end

function M.remove_unused_imports(is_sync)
  organize_imports_mode(c.OrganizeImportsMode.RemoveUnused, is_sync)
end

---@param is_sync boolean
function M.go_to_source_definition(is_sync)
  local params = vim.lsp.util.make_position_params()

  params.context = { source_definition = true }

  if is_sync then
    local res = vim.lsp.buf_request_sync(0, c.LspMethods.Definition, params, timeout)
    local typescript_client = get_typescript_client(0)
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
  local client = utils.get_clients {
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

---@param is_sync boolean
function M.rename_file(is_sync)
  local source = vim.api.nvim_buf_get_name(0)

  a.void(function()
    local newSource = async.ui_input { prompt = "New path: ", default = source }

    if not newSource then
      return
    end

    local err, result = async.buf_request_isomorphic(is_sync, 0, c.LspMethods.WillRenameFiles, {
      files = {
        {
          oldUri = vim.uri_from_fname(source),
          newUri = vim.uri_from_fname(newSource),
        },
      },
    })

    local changes = result and result.changes
    if not err and changes then
      local fs_err = uv.fs_stat(newSource)
      if not fs_err then
        au.scheduler()
        vim.notify_once("[typescript-tools] Cannot rename to exitsting file!", vim.log.levels.ERROR)
        return
      end

      fs_err = uv.fs_rename(source, newSource)
      assert(not fs_err, fs_err)

      au.scheduler()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == source then
          vim.api.nvim_buf_set_name(bufnr, newSource)
        end
      end

      vim.lsp.util.apply_workspace_edit(result or {}, "utf-8")
    end
  end)()
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
  utils.add_reverse_lookup(codes)
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

---JsxClosingTag feature impl
---@param bufnr integer
---@param params table
---@param cb fun()
---@param pre_request_id integer|nil
function M.jsx_close_tag(bufnr, params, cb, pre_request_id)
  local typescript_client = get_typescript_client(bufnr)
  if typescript_client == nil then
    return nil
  end
  if pre_request_id ~= nil then
    typescript_client.cancel_request(pre_request_id)
  end
  local changedtick = vim.api.nvim_buf_get_var(bufnr, "changedtick")

  local _, request_id = typescript_client.request(
    c.CustomMethods.JsxClosingTag,
    params,
    ---@param data { newText: string, caretOffset: number }
    function(err, data)
      if
        err ~= nil
        or data == nil
        or vim.tbl_isempty(data)
        or bufnr ~= vim.api.nvim_get_current_buf()
        or changedtick ~= vim.api.nvim_buf_get_var(bufnr, "changedtick")
      then
        return
      end

      vim.lsp.util.apply_text_edits({
        {
          range = {
            start = params.position,
            ["end"] = params.position,
          },
          newText = data.newText,
        },
      }, bufnr, "utf-8")

      vim.api.nvim_win_set_cursor(0, { params.position.line + 1, params.position.character })

      cb()
    end,
    bufnr
  )

  return request_id
end

---@param is_sync boolean
function M.file_references(is_sync)
  a.void(function()
    local client = utils.get_typescript_client(0)

    if not client then
      return
    end

    local err, result = async.buf_request_isomorphic(
      is_sync,
      0,
      c.CustomMethods.FileReferences,
      { textDocument = vim.lsp.util.make_text_document_params() }
    )

    vim.lsp.handlers[c.LspMethods.Reference](err, result, { client_id = client.id })
  end)()
end

---@param tmpfile string
function M.save_snapshot_to(tmpfile)
  async.buf_request_isomorphic(
    true,
    0,
    c.CustomMethods.SaveTo,
    { textDocument = vim.lsp.util.make_text_document_params(), tmpfile = tmpfile }
  )
end

return M
