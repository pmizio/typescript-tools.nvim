local log = require "vim.lsp.log"
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.utils"
local proto_utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

local severity_map = {
  suggestion = c.DiagnosticSeverity.Hint,
  warning = c.DiagnosticSeverity.Warning,
  error = c.DiagnosticSeverity.Error,
}

-- Stealed from vscode source:
-- https://github.com/microsoft/vscode/blob/401d89f2cb622496857f13741f5535e4be4589be/extensions/typescript-language-features/src/typeScriptServiceClientHost.ts#L40
local stylecheck_diagnostics = {
  -- variable declared but never used
  6196,
  6133,
  -- property declareted but never used
  6138,
  -- all imports are unused
  6192,
  -- unreachable code
  7027,
  -- unused label
  7028,
  -- fall through case in switch
  7029,
  -- not all code paths return a value
  7030,
}
utils.add_reverse_lookup(stylecheck_diagnostics)

--- @param diagnostic table
--- @return DiagnosticSeverity
local function category_to_severity(diagnostic)
  local severity = severity_map[diagnostic.category]

  if severity == c.DiagnosticSeverity.Error and stylecheck_diagnostics[diagnostic.code] then
    return c.DiagnosticSeverity.Warning
  end

  if not severity then
    local _ = log.warn()
      and log.warn("tsserver", "cannot find correct severity for: ", diagnostic.category)
    return c.DiagnosticSeverity.Error
  end

  return severity
end

--- @param related_information table
--- @return table
local function convert_related_information(related_information)
  return vim.tbl_map(function(info)
    return {
      message = info.message,
      location = {
        uri = vim.uri_from_fname(info.span.file),
        range = proto_utils.convert_tsserver_range_to_lsp(info.span),
      },
    }
  end, related_information)
end

---@param diagnostic table
---@return table<DiagnosticTag>
local function get_diagnostic_tags(diagnostic)
  local tags = {}

  if diagnostic.reportsUnnecessary then
    table.insert(tags, c.DiagnosticTag.Unnecessary)
  end

  if diagnostic.reportsDeprecated then
    table.insert(tags, c.DiagnosticTag.Deprecated)
  end

  return tags
end

--- @return string[]
local function get_attached_buffers()
  local client = utils.get_clients({ name = plugin_config.plugin_name })[1]

  if client then
    local attached_bufs = {}

    for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
      if vim.lsp.buf_is_attached(bufnr, client.id) and not utils.is_buf_hidden(bufnr) then
        table.insert(attached_bufs, vim.api.nvim_buf_get_name(bufnr))
      end
    end

    return attached_bufs
  end

  return {}
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  local requested_buf = vim.uri_to_fname(text_document.uri)
  local files = { requested_buf }

  for _, buf in pairs(get_attached_buffers()) do
    if requested_buf ~= buf then
      table.insert(files, buf)
    end
  end

  request {
    command = c.CommandTypes.Geterr,
    arguments = {
      delay = 0,
      files = files,
    },
  }

  -- INFO:  it's ok, we wait for response command
  local body, command = coroutine.yield() -- luacheck: ignore
  local cache = {}

  repeat
    local file = body.file and vim.uri_from_fname(body.file)

    if file and not cache[file] then
      cache[file] = {}
    end

    for _, diagnostic in pairs(body.diagnostics or {}) do
      table.insert(cache[file], {
        message = diagnostic.text,
        source = c.DiagnosticSource,
        code = diagnostic.code,
        severity = category_to_severity(diagnostic),
        range = proto_utils.convert_tsserver_range_to_lsp(diagnostic),
        relatedInformation = diagnostic.relatedInformation
          and convert_related_information(diagnostic.relatedInformation),
        tags = get_diagnostic_tags(diagnostic),
      })
    end

    body, command = coroutine.yield()
  until command == c.DiagnosticEventKind.RequestCompleted

  local diagnostic_report = {
    kind = c.DocumentDiagnosticReportKind.Full,
    -- INFO: for now nvim not implement diagnostic pull model but we want to be ready for it
    items = {},
    relatedDocuments = {},
  }

  for uri, diagnostics in pairs(cache) do
    diagnostic_report.relatedDocuments[uri] = {
      kind = c.DocumentDiagnosticReportKind.Full,
      items = diagnostics,
    }
  end

  response(diagnostic_report)
end

M.interrupt_diagnostic = false

return M
