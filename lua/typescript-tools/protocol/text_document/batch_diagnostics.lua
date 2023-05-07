local log = require "vim.lsp.log"
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

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
    log.warn("[tsserver] cannot find correct severity for: " .. category)
    return c.DiagnosticSeverity.Error
  end

  return severity
end

--- @param related_information table
--- @return table
local convert_related_information = function(related_information)
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

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  request {
    command = c.CommandTypes.Geterr,
    arguments = {
      delay = 0,
      files = params.files,
    },
  }

  -- ---@param body table
  -- ---@param command DiagnosticEventKind | string
  -- ---@return table
  -- local function handler(body, command)
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
        range = utils.convert_tsserver_range_to_lsp(diagnostic),
        relatedInformation = diagnostic.relatedInformation
          and convert_related_information(diagnostic.relatedInformation),
      })
    end

    body, command = coroutine.yield()
  until command == c.DiagnosticEventKind.RequestCompleted

  response(cache)
end

return M
