local log = require "vim.lsp.log"
local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local HandlerCoroutine = require("typescript-tools.protocol.utils").HandlerCoroutine

local SOURCE = "tsserver"

local severity_map = {
  suggestion = constants.DiagnosticSeverity.Hint,
  warning = constants.DiagnosticSeverity.Warning,
  error = constants.DiagnosticSeverity.Error,
}

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L818
local function diagnostics_request_handler(_, params)
  local text_document = params.textDocument

  return {
    command = constants.CommandTypes.Geterr,
    arguments = {
      delay = 0,
      files = text_document and { vim.uri_to_fname(text_document.uri) }
        or vim.tbl_map(function(file)
          return vim.uri_to_fname(file)
        end, params.files),
    },
  }
end

--- @private
--- @param category number
--- @return number
local function category_to_severity(category)
  local severity = severity_map[category]
  if not severity then
    log.warn("[tsserver] cannot find correct severity for: " .. category)
    return constants.DiagnosticSeverity.Error
  end

  return severity
end

--- @private
--- @param related_information table
--- @return table
local function convert_related_information(related_information)
  return vim.tbl_map(function(info)
    return {
      message = info.message,
      location = {
        uri = vim.uri_from_fname(info.span.file),
        range = utils.convert_tsserver_range_to_lsp(info.span),
      },
    }
  end, related_information)
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/8a1b85880f89c9cff606c5844e8883e5f483c7db/lib/protocol.d.ts#L844
local function diagnostics_response_worker(a, b, c)
  local cache = {}

  while true do
    local event, body, request_params = coroutine.yield()

    if event == constants.RequestCompletedEventName then
      if request_params.files then
        return cache
      end

      return {
        kind = constants.DiagnosticReportKind.Full,
        items = vim.tbl_values(cache)[1] or {},
      }
    end

    local file = vim.uri_from_fname(body.file)

    for _, diagnostic in pairs(body.diagnostics) do
      if not cache[file] then
        cache[file] = {}
      end

      table.insert(cache[file], {
        message = diagnostic.text,
        source = SOURCE,
        code = diagnostic.code,
        severity = category_to_severity(diagnostic.category),
        range = utils.convert_tsserver_range_to_lsp(diagnostic),
        relatedInformation = diagnostic.relatedInformation
          and convert_related_information(diagnostic.relatedInformation),
      })
    end
  end
end

local diagnostics_response_handler = HandlerCoroutine:new(diagnostics_response_worker)

return {
  diagnostics_response_handler = diagnostics_response_handler,
  request = {
    {
      method = constants.LspMethods.Diagnostic,
      handler = diagnostics_request_handler,
    },
    {
      method = constants.CustomMethods.BatchDiagnostic,
      handler = diagnostics_request_handler,
    },
  },
  response = {
    {
      method = constants.DiagnosticEventKind.SyntaxDiag,
      handler = diagnostics_response_handler,
    },
    {
      method = constants.DiagnosticEventKind.SemanticDiag,
      handler = diagnostics_response_handler,
    },
    {
      method = constants.DiagnosticEventKind.SuggestionDiag,
      handler = diagnostics_response_handler,
    },
    {
      method = constants.RequestCompletedEventName,
      handler = diagnostics_response_handler,
    },
  },
}
