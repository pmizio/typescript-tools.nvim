local log = require "vim.lsp.log"
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.utils"
local proto_utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

local SOURCE = "tsserver"

local SEVERITY_MAP = {
  suggestion = c.DiagnosticSeverity.Hint,
  warning = c.DiagnosticSeverity.Warning,
  error = c.DiagnosticSeverity.Error,
}

--- @param category number
--- @return DiagnosticSeverity
local function category_to_severity(category)
  local severity = SEVERITY_MAP[category]
  if not severity then
    local _ = log.warn() and log.warn("tsserver", "cannot find correct severity for: ", category)
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
  local client = vim.lsp.get_active_clients({ name = plugin_config.plugin_name })[1]

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
        source = SOURCE,
        code = diagnostic.code,
        severity = category_to_severity(diagnostic.category),
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
